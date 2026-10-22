# A tenant that relies on objects owned by someone else:
# - by ID, for objects whose IDs are passed in (no lookup at plan time);
# - by name, for objects that already exist and are looked up.
# Runs with a member role on the project; the project is the one of the token.

module "tenant" {
  source = "../.."

  tenant = {
    existing = {
      networks = {
        transit    = { id = var.transit_network_id, subnets = { site-a = { id = var.transit_subnet_id } } }
        management = { name = "management", subnets = { site-a = { name = "management-site-a" } } }
      }
      security_groups = {
        ssh      = { name = "baseline-ssh" }
        dhcp     = { name = "baseline-dhcp" }
        ssh-out  = { name = "baseline-ssh-egress" }
        monitors = { id = var.monitoring_security_group_id }
      }
      dns_zones = {
        own    = { name = "demo.example.org." }       # owned by this project
        shared = { id = var.shared_services_zone_id } # owned by the administrator, shared with this project
      }
    }

    networks = {
      app = {
        mtu = 1400
        subnets = {
          main = {
            cidr             = "10.20.5.0/24"
            gateway_ip       = "10.20.5.1"
            allocation_pools = [{ start = "10.20.5.20", end = "10.20.5.250" }]
          }
        }
        routers = {
          to-transit = {
            external_network = "transit"
            external_subnet  = "site-a"
            internal_subnet  = "main"
            internal_ip      = "10.20.5.10"
            advertise_routes = ["10.10.0.0/22"]
          }
        }
      }
    }

    management_port = {
      network                = "management"
      security_groups        = ["ssh", "dhcp"]
      egress_security_groups = ["ssh-out"]
    }

    instances = {
      db-1 = {
        az     = "site-a"
        flavor = "m1.large"

        management_port = true
        boot            = { source = "existing", name = "db-1-root" } # rebuild on a surviving root volume
        ports = {
          main = { network = "app", subnet = "main", fixed_ip = "10.20.5.30", security_groups = ["monitors"] }
        }
        volumes = {
          data = { existing = { id = var.db_data_volume_id } } # created and protected outside the module
        }
        labels = ["database"]
      }
    }

    dns = {
      records = {
        db-internal = { zone = "own", name = "db", type = "A", records = ["10.20.5.30"] }
        db-service  = { zone = "shared", name = "db.demo", type = "CNAME", records = ["db.demo.example.org."] }
      }
    }
  }
}
