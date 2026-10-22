# A complete tenant in one stack, for evaluation and labs.
# The module creates its own project, which requires admin credentials.

module "cloudinit" {
  source   = "../../modules/cloudinit"
  for_each = toset(["app-1", "app-2"])

  hostname = each.key
  users = {
    ops = { ssh_authorized_keys = [var.ssh_public_key], sudo = true }
  }
  disks = {
    data = { device = "/dev/vdb", filesystem = "ext4", mountpoint = "/srv/data" }
  }
  packages = ["htop"]
}

module "tenant" {
  source = "../.."

  tenant = {
    project = {
      create      = true
      name        = "lab"
      description = "Evaluation tenant"
      quotas = {
        compute = { cores = 8, ram = 16384, instances = 4 }
        network = { floatingip = 2 }
      }
    }

    existing = {
      networks = { public = { name = "public", subnets = { v4 = { name = "public-subnet" } } } }
    }

    networks = {
      app = {
        subnets = { main = { cidr = "192.168.10.0/24", dns_nameservers = ["9.9.9.9"] } }
        routers = { out = { external_network = "public", internal_subnet = "main" } }
      }
    }

    security_groups = {
      ssh = {
        rules = { in = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = var.admin_cidr } }
      }
      web = {
        rules = {
          http  = { direction = "ingress", protocol = "tcp", port_min = 80, port_max = 80, remote_ip_prefix = "0.0.0.0/0" }
          https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" }
        }
      }
    }

    instances = {
      for name in ["app-1", "app-2"] : name => {
        az        = "nova"
        flavor    = "m1.small"
        image     = "ubuntu-24.04"
        user_data = module.cloudinit[name].rendered
        labels    = ["app"]
        ports = {
          main = {
            network         = "app"
            subnet          = "main"
            security_groups = ["ssh", "web"]
            floating_ip     = { pool = "public" }
          }
        }
        volumes = { data = { size = 10 } }
      }
    }
  }
}
