# Stage 02 — one instance with everything around it.
# Creates: network + router, security group, 1 instance booting from a new
# 10 GB root volume, 1 data volume (1 GB) formatted and mounted by the
# cloudinit module, 1 floating IP, 2 DNS records in the zone owned by the
# project (one on the floating IP, one on the fixed IP).
# Checks: empty plan after apply; boot from volume; cloud-init disk unit
# (console log contains "disk-data: formatting"); DNS records resolve in Designate.

module "cloudinit" {
  source = "../../../modules/cloudinit"

  hostname = "it02-vm"
  disks    = { data = { device = "/dev/vdb", mountpoint = "/srv/data" } }
}

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks  = { ext = { name = var.external_network } }
      dns_zones = { own = { name = var.zone_name } }
    }

    networks = {
      it02-net = {
        subnets = { main = { cidr = "192.168.152.0/24", dns_nameservers = var.dns_nameservers } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    security_groups = {
      it02-ssh = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "0.0.0.0/0" } }
      }
    }

    instances = {
      it02-vm = {
        az        = var.az
        flavor    = var.flavor_nodisk
        image     = var.image
        boot      = { source = "volume", size = 10 }
        user_data = module.cloudinit.rendered
        labels    = ["integration-test"]
        ports = {
          main = {
            network         = "it02-net"
            subnet          = "main"
            security_groups = ["it02-ssh"]
            floating_ip     = { pool = "ext", dns = [{ name = "it02-vm", zone = "own" }] }
            dns             = [{ name = "it02-vm-int", zone = "own" }]
          }
        }
        volumes = { data = { size = 1 } }
      }
    }
  }
}

output "instances" {
  value = module.tenant.instances
}
