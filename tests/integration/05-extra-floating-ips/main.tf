# Stage 05 — a port with floating IPs from two external networks.
# Creates: 1 network with 2 routers ("out" to the external network, default gateway;
# "transit" to a second external network, advertising its range); 1 instance whose
# port has a primary floating IP on the external network and an extra floating IP on
# the second one, each with an A record when a zone is given.
# Checks: empty plan after apply; both floating IPs ACTIVE on the same fixed IP;
# outputs floating_ip, floating_ips and the port id.

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks = {
        ext     = { name = var.external_network }
        transit = { name = coalesce(var.second_external_network, var.external_network) }
      }
      dns_zones = { for k, z in { own = { name = var.zone_name } } : k => z if var.zone_name != null }
    }

    networks = {
      it05-app = {
        subnets = { main = { cidr = "192.168.156.0/24", dns_nameservers = var.dns_nameservers } }
        routers = {
          a-out     = { external_network = "ext", internal_subnet = "main" }
          b-transit = { external_network = "transit", internal_subnet = "main", advertise_routes = [var.second_external_cidr] }
        }
      }
    }

    instances = {
      it05-app-1 = {
        az     = var.az
        flavor = var.flavor
        image  = var.image
        ports = {
          main = {
            network     = "it05-app"
            subnet      = "main"
            floating_ip = { pool = "ext", dns = [for n in ["it05-primary"] : { name = n, zone = "own" } if var.zone_name != null] }
            extra_floating_ips = {
              transit = { pool = "transit", dns = [for n in ["it05-transit"] : { name = n, zone = "own" } if var.zone_name != null] }
            }
          }
        }
      }
    }
  }
}

output "instances" {
  value = module.tenant.instances
}
