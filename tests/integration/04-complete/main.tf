# Stage 04 — the rest of the model in one tenant.
# Creates: 2 networks (app, mgmt); on the app subnet, 2 routers: "out" to the
# external network (default gateway, first in key order) and "transit" to a
# second external network, advertising a route; security groups with a rule
# between local groups; an adopted shared security group (by name); 1 instance
# with a management port on the mgmt network; 1 free DNS record (CNAME).
# Checks: empty plan after apply; host route present on the app subnet; the
# management port exists under the key "management".

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks = {
        ext     = { name = var.external_network }
        transit = { name = var.second_external_network }
      }
      security_groups = { baseline = { name = var.shared_security_group } }
      dns_zones       = { own = { name = var.zone_name } }
    }

    networks = {
      it04-app = {
        subnets = { main = { cidr = "192.168.154.0/24", dns_nameservers = var.dns_nameservers } }
        routers = {
          a-out     = { external_network = "ext", internal_subnet = "main" }
          b-transit = { external_network = "transit", internal_subnet = "main", advertise_routes = [var.second_external_cidr] }
        }
      }
      it04-mgmt = {
        subnets = { main = { cidr = "192.168.155.0/24", dns_nameservers = var.dns_nameservers } }
      }
    }

    security_groups = {
      it04-bastion = {
        rules = { ssh-out = { direction = "egress", protocol = "tcp", port_min = 22, port_max = 22 } }
      }
      it04-app = {
        rules = { from-bastion = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_group = "it04-bastion" } }
      }
      it04-mgmt = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.155.0/24" } }
      }
    }

    management_port = { network = "it04-mgmt", security_groups = ["it04-mgmt"] }

    instances = {
      it04-app-1 = {
        az              = var.az
        flavor          = var.flavor
        image           = var.image
        management_port = true
        ports           = { main = { network = "it04-app", subnet = "main", security_groups = ["it04-app", "baseline"] } }
      }
    }

    dns = {
      records = { alias = { zone = "own", name = "it04-alias", type = "CNAME", records = ["it04-app-1.${var.zone_name}"] } }
    }
  }
}

output "instances" {
  value = module.tenant.instances
}

output "networks" {
  value = module.tenant.networks
}
