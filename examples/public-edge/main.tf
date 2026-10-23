# Two reverse proxies behind an Octavia load balancer: TCP passthrough on 443
# with the PROXY protocol so that backends see client addresses, HTTP on 80,
# a public floating IP and DNS records on it. Requires Octavia and Designate.

module "tenant" {
  source = "../.."

  tenant = {
    existing = {
      networks  = { public = { name = "public", subnets = { v4 = { name = "public-subnet" } } } }
      dns_zones = { site = { name = "example.org." } }
    }

    networks = {
      edge = {
        subnets = { main = { cidr = "192.168.40.0/24" } }
        routers = { out = { external_network = "public", internal_subnet = "main" } }
      }
    }

    security_groups = {
      proxy = {
        rules = {
          http  = { direction = "ingress", protocol = "tcp", port_min = 80, port_max = 80, remote_ip_prefix = "192.168.40.0/24" }
          https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "192.168.40.0/24" }
        }
      }
    }

    instances = {
      for name in ["proxy-1", "proxy-2"] : name => {
        az     = "nova"
        flavor = "m1.small"
        image  = "ubuntu-24.04"
        labels = ["reverse-proxy"]
        ports  = { main = { network = "edge", subnet = "main", security_groups = ["proxy"] } }
      }
    }

    load_balancers = {
      edge = {
        vip         = { network = "edge", subnet = "main" }
        flavor_id   = var.octavia_flavor_id # an active/standby flavor
        floating_ip = { pool = "public", dns = [{ name = "", zone = "site" }, { name = "www", zone = "site" }] }
        listeners = {
          http = {
            protocol = "HTTP", port = 80
            pool = {
              protocol = "HTTP", members = ["proxy-1.main", "proxy-2.main"]
              monitor  = { type = "HTTP", url_path = "/ping", expected_codes = "200" }
            }
          }
          https = {
            protocol = "TCP", port = 443
            pool = {
              protocol = "PROXY", members = ["proxy-1.main", "proxy-2.main"]
              monitor  = { type = "TCP" }
            }
          }
        }
      }
    }
  }
}

output "load_balancer" {
  description = "Virtual IP and floating IP of the load balancer."
  value       = module.tenant.load_balancers["edge"]
}
