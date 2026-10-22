# Short-lived layer: instances. It adopts the network layer's objects by ID,
# so changes to instances never touch the network layer's state.
# The backend and the way outputs are shared are your choice; local state is
# used here only to keep the example self-contained.

data "terraform_remote_state" "network" {
  backend = "local"
  config  = { path = "../network/terraform.tfstate" }
}

locals {
  net = data.terraform_remote_state.network.outputs
}

module "compute_layer" {
  source = "../../.."

  tenant = {
    existing = {
      networks = {
        app = {
          id      = local.net.networks["app"].id
          subnets = { main = { id = local.net.networks["app"].subnets["main"].id } }
        }
      }
      security_groups = { web = { id = local.net.security_groups["web"].id } }
    }

    instances = {
      web-1 = {
        az     = "nova"
        flavor = "m1.small"
        image  = "ubuntu-24.04"
        ports  = { main = { network = "app", subnet = "main", security_groups = ["web"] } }
      }
    }
  }
}

output "instances" {
  description = "Instances with their addresses."
  value       = module.compute_layer.instances
}
