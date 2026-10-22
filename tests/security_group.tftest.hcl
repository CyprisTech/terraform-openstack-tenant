mock_provider "openstack" {}

variables {
  name = "web"
  rules = {
    https     = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" }
    from-self = { direction = "ingress", remote_group_id = "self" }
    all-out   = { direction = "egress" }
  }
}

run "rules_keyed_by_name" {
  command = plan

  module {
    source = "./modules/security-group"
  }

  assert {
    condition     = toset(keys(openstack_networking_secgroup_rule_v2.this)) == toset(["https", "from-self", "all-out"])
    error_message = "Rules must be keyed by name."
  }

  assert {
    condition     = openstack_networking_secgroup_rule_v2.this["https"].port_range_min == 443
    error_message = "Port range must be passed through."
  }
}

run "rejects_cidr_and_group_together" {
  command = plan

  module {
    source = "./modules/security-group"
  }

  variables {
    rules = { bad = { direction = "ingress", remote_ip_prefix = "10.0.0.0/8", remote_group_id = "x" } }
  }

  expect_failures = [var.rules]
}

run "rejects_half_port_range" {
  command = plan

  module {
    source = "./modules/security-group"
  }

  variables {
    rules = { bad = { direction = "ingress", protocol = "tcp", port_min = 22 } }
  }

  expect_failures = [var.rules]
}
