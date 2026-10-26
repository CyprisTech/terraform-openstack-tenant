# Stage 03 — Octavia in front of two instances.
# Creates: network + router, 2 security groups (one referencing the other),
# 1 server group (soft anti-affinity), 2 instances booting from the image, 1 load balancer (default Octavia
# flavor), 1 TCP listener on port 22 with a TCP health monitor (sshd answers
# without any extra software), 1 floating IP on the VIP, 1 DNS record in the
# zone shared with the project.
# Checks: empty plan after apply; members ONLINE; record created in a shared zone.
# Duration: an amphora takes several minutes to build.

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks  = { ext = { name = var.external_network } }
      dns_zones = { for k, z in { shared = { name = var.shared_zone_name } } : k => z if var.shared_zone_name != null }
    }

    networks = {
      it03-net = {
        subnets = { main = { cidr = "192.168.153.0/24", dns_nameservers = var.dns_nameservers } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    security_groups = {
      it03-lb = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "0.0.0.0/0" } }
      }
      it03-web = {
        # From the load balancer group (rule created by the composite) and between members (self).
        rules = {
          from-lb         = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_group = "it03-lb" }
          from-vip-subnet = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.153.0/24" }
          peers           = { direction = "ingress", remote_group = "it03-web" }
        }
      }
    }

    # Soft anti-affinity: spread the two members over two hosts when possible,
    # without failing on a cloud with a single compute host.
    server_groups = { it03-web = { policy = "soft-anti-affinity" } }

    instances = {
      for n in ["it03-web-1", "it03-web-2"] : n => {
        server_group = "it03-web"
        az           = var.az
        flavor       = var.flavor
        image        = var.image
        ports        = { main = { network = "it03-net", subnet = "main", security_groups = ["it03-web"] } }
      }
    }

    load_balancers = {
      it03-edge = {
        vip             = { network = "it03-net", subnet = "main" }
        security_groups = ["it03-lb"]
        flavor_id       = var.lb_flavor_id
        floating_ip     = { pool = "ext", dns = [for d in [{ name = "it03-edge", zone = "shared" }] : d if var.shared_zone_name != null] }
        listeners = {
          ssh = {
            protocol = "TCP"
            port     = 22
            pool     = { protocol = "TCP", members = ["it03-web-1.main", "it03-web-2.main"], monitor = { type = "TCP" } }
          }
        }
      }
    }
  }
}

output "load_balancers" {
  value = module.tenant.load_balancers
}
