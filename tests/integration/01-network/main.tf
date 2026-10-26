# Stage 01 — network only.
# Creates: 1 network, 1 subnet, 1 router (gateway on the external network,
# internal address = subnet gateway), 1 router port, 1 security group + 1 rule.
# Checks: single plan, empty plan after apply, default gateway rule.

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks = { ext = { name = var.external_network } }
    }

    networks = {
      it01-net = {
        subnets = { main = { cidr = "192.168.151.0/24", dns_nameservers = var.dns_nameservers, gateway_ip = "192.168.151.1" } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    security_groups = {
      it01-ssh = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.151.0/24" } }
      }
    }
  }
}

output "networks" {
  value = module.tenant.networks
}

output "router_internal_ip" {
  description = "Must be 192.168.151.1: the only router of the subnet holds the subnet's gateway address."
  value       = module.tenant.networks["it01-net"].routers["out"].internal_ip
}
