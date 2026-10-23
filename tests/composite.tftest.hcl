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

    management_port = { network = "management", security_groups = ["ssh"] }

    instances = {
      for n in ["web-1", "web-2"] : n => {
        az              = "nova"
        flavor          = "m1.small"
        image           = "ubuntu-24.04"
        management_port = true
        labels          = ["web"]
        ports = {
          main = {
            network         = "app"
            subnet          = "main"
            security_groups = ["web"]
            dns             = [{ name = n, zone = "app" }]
          }
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
    condition     = toset(keys(module.instance["web-1"].ports)) == toset(["main", "management"])
    error_message = "The management port is added under the reserved key."
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
