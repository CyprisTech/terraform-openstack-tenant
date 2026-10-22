# Long-lived layer: networks, routers and security groups.
# Changes here are rare; this layer has its own state.

module "network_layer" {
  source = "../../.."

  tenant = {
    existing = {
      networks = { public = { name = "public", subnets = { v4 = { name = "public-subnet" } } } }
    }

    networks = {
      app = {
        subnets = { main = { cidr = "192.168.20.0/24" } }
        routers = { out = { external_network = "public", internal_subnet = "main" } }
      }
    }

    security_groups = {
      web = {
        rules = { https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" } }
      }
    }
  }
}

output "networks" {
  description = "Networks and subnets created by this layer, keyed by name."
  value       = module.network_layer.networks
}

output "security_groups" {
  description = "Security groups created by this layer, keyed by name."
  value       = module.network_layer.security_groups
}
