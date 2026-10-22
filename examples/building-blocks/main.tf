# The building blocks used directly, without the composite. Each block takes
# IDs as inputs (dependency inversion); wiring them together is your code.

data "openstack_networking_network_v2" "public" {
  name = "public"
}

module "network" {
  source = "../../modules/network"

  name    = "app"
  subnets = { main = { cidr = "192.168.30.0/24" } }
  routers = {
    out = {
      external_network_id = data.openstack_networking_network_v2.public.id
      internal_subnet     = "main"
    }
  }
}

module "web_sg" {
  source = "../../modules/security-group"

  name = "web"
  rules = {
    https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" }
  }
}

module "web" {
  source = "../../modules/instance"

  name   = "web-1"
  az     = "nova"
  flavor = "m1.small"
  image  = "ubuntu-24.04"
  ports = {
    main = {
      network_id         = module.network.id
      subnet_id          = module.network.subnets["main"].id
      security_group_ids = [module.web_sg.id]
    }
  }
}

output "web_ip" {
  description = "Fixed IP address of the instance."
  value       = module.web.ports["main"].ip
}
