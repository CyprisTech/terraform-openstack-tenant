# The smallest useful tenant, on a cloud without Octavia or Designate.
# Nothing in the composite requires those services when the model does not
# use load_balancers or dns.

module "tenant" {
  source = "../.."

  tenant = {
    existing = {
      networks = { ext = { name = "external", subnets = { v4 = { name = "external-v4" } } } }
    }

    networks = {
      app = {
        subnets = { main = { cidr = "10.0.0.0/24" } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    instances = {
      vm-1 = {
        az     = "nova"
        flavor = "m1.small"
        image  = "ubuntu-24.04"
        ports  = { main = { network = "app", subnet = "main", floating_ip = { pool = "external" } } }
      }
    }
  }
}

output "instances" {
  description = "Instances with their addresses."
  value       = module.tenant.instances
}
