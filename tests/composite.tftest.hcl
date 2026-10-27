# The composite on a complete tenant, with mocked providers: the plan must
# succeed in one pass, and every collection must be keyed by input keys.

mock_provider "openstack" {
  mock_resource "openstack_networking_port_v2" {
    defaults = {
      all_fixed_ips = ["192.0.2.10"]
    }
  }
  mock_resource "openstack_networking_floatingip_v2" {
    defaults = {
      address = "203.0.113.10"
    }
  }
  mock_data "openstack_networking_network_v2" {
    defaults = {
      id = "net-adopted"
    }
  }
}

variables {
  tenant = {
    existing = {
      networks = {
        public     = { name = "public", subnets = { v4 = { name = "public-v4" } } }
        management = { id = "net-mgmt", subnets = { site-a = { id = "sub-mgmt" } } }
      }
      security_groups = { ssh = { name = "baseline-ssh" } }
      dns_zones       = { shared = { id = "zone-shared", name = "svc.example.org." } }
    }

    networks = {
      app = {
        subnets = { main = { cidr = "192.168.10.0/24" } }
        routers = { out = { external_network = "public", external_subnet = "v4", internal_subnet = "main", internal_ip = "192.168.10.1" } }
      }
    }

    security_groups = {
      lb  = { rules = { https = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" } } }
      web = { rules = { from-lb = { direction = "ingress", protocol = "tcp", port_min = 8443, port_max = 8443, remote_group = "lb" }, peers = { direction = "ingress", remote_group = "web" } } }
    }

    server_groups = { web = { policy = "soft-anti-affinity" } }

    instances = {
      for n in ["web-1", "web-2"] : n => {
        az           = "nova"
        flavor       = "m1.small"
        image        = "ubuntu-24.04"
        server_group = "web"
        labels       = ["web"]
        ports = {
          main = {
            network         = "app"
            subnet          = "main"
            security_groups = ["web"]
            dns             = [{ name = n, zone = "app" }]
          }
          mgmt = { network = "management", subnet = "site-a", security_groups = ["ssh"] }
        }
      }
    }

    load_balancers = {
      edge = {
        vip             = { network = "app", subnet = "main" }
        security_groups = ["lb"]
        floating_ip     = { pool = "public", dns = [{ name = "www", zone = "shared" }] }
        listeners = {
          https = {
            protocol = "TCP", port = 443
            pool     = { protocol = "PROXY", member_port = 8443, members = ["web-1.main", "web-2.main"], monitor = { type = "TCP" } }
          }
        }
      }
    }

    dns = {
      zones   = { app = { name = "app.example.org.", email = "hostmaster@example.org" } }
      records = { api = { zone = "shared", name = "api", type = "CNAME", records = ["www.svc.example.org."] } }
    }
  }
}

run "single_plan_on_a_complete_tenant" {
  command = plan

  assert {
    condition     = toset(keys(module.instance)) == toset(["web-1", "web-2"])
    error_message = "Instances are keyed by name."
  }

  assert {
    condition     = toset(keys(module.instance["web-1"].ports)) == toset(["main", "mgmt"])
    error_message = "A second port on another network is just another port."
  }

  assert {
    condition     = openstack_compute_servergroup_v2.this["web"].policies == tolist(["soft-anti-affinity"])
    error_message = "Server groups are created with their policy."
  }

  assert {
    condition     = toset(keys(openstack_networking_secgroup_rule_v2.cross_group)) == toset(["web/from-lb"])
    error_message = "Rules referencing another local group are created by the composite; self references stay in the module."
  }

  assert {
    condition     = toset(keys(output.instances)) == toset(["web-1", "web-2"]) && toset(keys(output.load_balancers)) == toset(["edge"])
    error_message = "Outputs are keyed like the input."
  }

  assert {
    condition     = output.instances["web-1"].labels == tolist(["web"])
    error_message = "Labels are part of the output contract."
  }

  assert {
    condition     = toset(keys(output.networks)) == toset(["app"]) && toset(keys(output.security_groups)) == toset(["lb", "web"]) && toset(keys(output.dns_zones)) == toset(["app"])
    error_message = "Only created objects appear in networks, security_groups and dns_zones."
  }
}

run "rejects_unknown_member" {
  command = plan

  variables {
    tenant = {
      networks = { app = { subnets = { main = { cidr = "10.0.0.0/24" } } } }
      instances = {
        a = { az = "nova", flavor = "m1", image = "img", ports = { main = { network = "app", subnet = "main" } } }
      }
      load_balancers = {
        lb = {
          vip       = { network = "app", subnet = "main" }
          listeners = { http = { protocol = "HTTP", port = 80, pool = { protocol = "HTTP", members = ["a.nope"] } } }
        }
      }
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_unknown_security_group" {
  command = plan

  variables {
    tenant = {
      networks  = { app = { subnets = { main = { cidr = "10.0.0.0/24" } } } }
      instances = { a = { az = "nova", flavor = "m1", image = "img", ports = { main = { network = "app", subnet = "main", security_groups = ["nope"] } } } }
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_floating_ip_pool_not_adopted" {
  command = plan

  variables {
    tenant = {
      networks  = { app = { subnets = { main = { cidr = "10.0.0.0/24" } } } }
      instances = { a = { az = "nova", flavor = "m1", image = "img", ports = { main = { network = "app", subnet = "main", floating_ip = { pool = "public" } } } } }
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_undeclared_subnet" {
  command = plan

  variables {
    tenant = {
      existing  = { networks = { shared = { name = "shared" } } }
      instances = { a = { az = "nova", flavor = "m1", image = "img", ports = { main = { network = "shared", subnet = "v4" } } } }
    }
  }

  expect_failures = [var.tenant]
}

run "extra_floating_ips" {
  command = plan

  variables {
    tenant = {
      existing = {
        networks = {
          svc_public = { name = "svc-public" }
          monitoring = { name = "monitoring", subnets = { v4 = { id = "sub-mon" } } }
        }
        dns_zones = { mon = { id = "zone-mon", name = "mon.example.org." } }
      }
      networks = {
        app = {
          subnets = { main = { cidr = "192.0.2.0/24" } }
          routers = {
            out = { external_network = "svc_public", internal_subnet = "main" }
            mon = { external_network = "monitoring", internal_subnet = "main", advertise_routes = ["198.51.100.0/24"] }
          }
        }
      }
      instances = {
        a = {
          az = "nova", flavor = "m1", image = "img"
          ports = {
            main = {
              network            = "app"
              subnet             = "main"
              floating_ip        = { pool = "svc_public" }
              extra_floating_ips = { monitoring = { pool = "monitoring", subnet = "v4", dns = [{ name = "a", zone = "mon" }] } }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = keys(output.instances["a"].ports["main"].floating_ips) == ["monitoring"]
    error_message = "floating_ips maps the labels of extra floating IPs to their addresses."
  }

  assert {
    condition     = output.instances["a"].ports["main"].fqdn == "a.mon.example.org."
    error_message = "A port whose only DNS name is on an extra floating IP exposes it as fqdn."
  }
}

run "rejects_extra_floating_ip_on_the_primary_pool" {
  command = plan

  variables {
    tenant = {
      existing = { networks = { public = { name = "public" } } }
      networks = { app = { subnets = { main = { cidr = "192.0.2.0/24" } } } }
      instances = {
        a = {
          az    = "nova", flavor = "m1", image = "img"
          ports = { main = { network = "app", subnet = "main", floating_ip = { pool = "public" }, extra_floating_ips = { again = { pool = "public" } } } }
        }
      }
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_extra_floating_ip_pool_not_adopted" {
  command = plan

  variables {
    tenant = {
      existing = { networks = { public = { name = "public" } } }
      networks = { app = { subnets = { main = { cidr = "192.0.2.0/24" } } } }
      instances = {
        a = {
          az    = "nova", flavor = "m1", image = "img"
          ports = { main = { network = "app", subnet = "main", floating_ip = { pool = "public" }, extra_floating_ips = { monitoring = { pool = "monitoring" } } } }
        }
      }
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_unknown_zone_on_extra_floating_ip" {
  command = plan

  variables {
    tenant = {
      existing = { networks = { monitoring = { name = "monitoring" } } }
      networks = { app = { subnets = { main = { cidr = "192.0.2.0/24" } } } }
      instances = {
        a = {
          az    = "nova", flavor = "m1", image = "img"
          ports = { main = { network = "app", subnet = "main", extra_floating_ips = { monitoring = { pool = "monitoring", dns = [{ name = "a", zone = "nope" }] } } } }
        }
      }
    }
  }

  expect_failures = [var.tenant]
}
