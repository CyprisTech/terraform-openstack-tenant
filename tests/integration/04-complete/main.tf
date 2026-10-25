# Stage 04 — the rest of the model in one tenant.
# Creates: 2 networks (app, mgmt); on the app subnet, 2 routers: "out" to the
# external network (default gateway, first in key order) and "transit" to a
# second external network, advertising a route; security groups with a rule
# between local groups; an adopted shared security group (by name); 1 instance
# with a second port on the mgmt network; 1 free DNS record (CNAME).
# Checks: empty plan after apply; host route present on the app subnet; the
# second port exists under the key "mgmt".

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks = {
        ext     = { name = var.external_network }
        transit = { name = coalesce(var.second_external_network, var.external_network) }
      }
      security_groups = { for k, g in { baseline = { name = var.shared_security_group } } : k => g if var.shared_security_group != null }
      dns_zones       = { for k, z in { own = { name = var.zone_name } } : k => z if var.zone_name != null }
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


    instances = {
      it04-app-1 = {
        az     = var.az
        flavor = var.flavor
        image  = var.image
        ports = {
          main = { network = "it04-app", subnet = "main", security_groups = concat(["it04-app"], var.shared_security_group == null ? [] : ["baseline"]) }
          mgmt = { network = "it04-mgmt", subnet = "main", security_groups = ["it04-mgmt"] }
        }
      }
    }

    dns = {
      records = { for k, r in { alias = { zone = "own", name = "it04-alias", type = "CNAME", records = ["it04-app-1.${coalesce(var.zone_name, "-.")}"] } } : k => r if var.zone_name != null }
    }
  }
}

output "instances" {
  value = module.tenant.instances
}

output "networks" {
  value = module.tenant.networks
}
