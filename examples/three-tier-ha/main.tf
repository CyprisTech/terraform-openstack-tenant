# Three-tier application with high availability on a single OpenStack project.
# See README.md for the architecture, the decisions and their trade-offs.

locals {
  cidr = "10.30.0.0/24"

  # Two replicas per tier, spread over compute hosts by server groups.
  tiers = {
    web  = { count = 2, group = "web" }
    app  = { count = 2, group = "app" }
    data = { count = 2, group = "data" }
  }

  nodes = merge([
    for tier, t in local.tiers : {
      for i in range(1, t.count + 1) : "${tier}-${i}" => { tier = tier, group = t.group }
    }
  ]...)
}

module "cloudinit" {
  source   = "../../modules/cloudinit"
  for_each = merge(local.nodes, { bastion = { tier = "bastion", group = null } })

  hostname = each.key
  users    = { ops = { ssh_authorized_keys = [var.ssh_public_key], sudo = true } }

  # The data tier keeps its files on a dedicated volume, formatted only when
  # empty and mounted by label at every boot.
  disks = each.value.tier == "data" ? {
    data = { device = "/dev/vdb", mountpoint = "/var/lib/postgresql", owner = "root", mode = "0755" }
  } : {}
}

module "tenant" {
  source = "../.."

  tenant = {
    existing = {
      networks  = { ext = { name = var.external_network } }
      dns_zones = { for k, z in { site = { name = var.zone_name } } : k => z if var.zone_name != null }
    }

    networks = {
      app = {
        subnets = { main = { cidr = local.cidr, dns_nameservers = var.dns_nameservers } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    security_groups = {
      # On the load balancer VIP: HTTPS from anywhere.
      lb = {
        rules = { https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" } }
      }
      # Web tier: traffic from the amphora, which reaches members from its own
      # address in the member subnet, not from the VIP port (see README).
      web = {
        rules = { from-lb = { direction = "ingress", protocol = "tcp", port_min = 8443, port_max = 8443, remote_ip_prefix = local.cidr } }
      }
      # Each tier only accepts the tier above it.
      app = {
        rules = { from-web = { direction = "ingress", protocol = "tcp", port_min = 8080, port_max = 8080, remote_group = "web" } }
      }
      data = {
        rules = {
          from-app    = { direction = "ingress", protocol = "tcp", port_min = 5432, port_max = 5432, remote_group = "app" }
          replication = { direction = "ingress", protocol = "tcp", port_min = 5432, port_max = 5432, remote_group = "data" }
        }
      }
      # Administration: SSH only through the bastion.
      bastion = {
        # Keyed by the CIDR itself, so adding a range never touches the others.
        rules = {
          for c in var.admin_cidrs : "ssh-${replace(replace(c, ".", "-"), "/", "-")}" => {
            direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = c
          }
        }
      }
      from-bastion = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_group = "bastion" } }
      }
    }

    # Hard anti-affinity for the data tier: two replicas on one host would lose
    # both copies with that host. Soft for stateless tiers, which can be
    # rescheduled.
    server_groups = {
      web  = { policy = "soft-anti-affinity" }
      app  = { policy = "soft-anti-affinity" }
      data = { policy = "anti-affinity" }
    }

    instances = merge(
      {
        for name, n in local.nodes : name => {
          az           = var.az
          flavor       = var.flavor
          image        = var.image
          server_group = n.group
          user_data    = module.cloudinit[name].rendered
          labels       = [n.tier]
          ports = {
            main = { network = "app", subnet = "main", security_groups = [n.tier, "from-bastion"] }
          }
          volumes = n.tier == "data" ? { data = { size = 20 } } : {}
        }
      },
      {
        bastion = {
          az        = var.az
          flavor    = var.flavor
          image     = var.image
          user_data = module.cloudinit["bastion"].rendered
          labels    = ["bastion"]
          ports = {
            main = {
              network         = "app"
              subnet          = "main"
              security_groups = ["bastion"]
              floating_ip     = { pool = "ext", dns = [for d in [{ name = "bastion", zone = "site" }] : d if var.zone_name != null] }
            }
          }
        }
      },
    )

    load_balancers = {
      edge = {
        vip             = { network = "app", subnet = "main" }
        security_groups = ["lb"]
        floating_ip     = { pool = "ext", dns = [for d in [{ name = "www", zone = "site" }] : d if var.zone_name != null] }
        listeners = {
          https = {
            protocol = "TCP", port = 443
            # TLS ends on the web tier; PROXY passes client addresses to it.
            pool = {
              protocol    = "PROXY"
              member_port = 8443
              members     = [for name, n in local.nodes : "${name}.main" if n.tier == "web"]
              monitor     = { type = "TCP" }
            }
          }
        }
      }
    }
  }
}
