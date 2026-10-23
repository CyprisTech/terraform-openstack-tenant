# Mocked tests: no cloud required. They check that resource keys come from
# the input only, so that a single plan is enough.

mock_provider "openstack" {
  # all_fixed_ips is computed by Neutron; on a real cloud it is unknown at
  # plan time, the mock needs a concrete value.
  mock_resource "openstack_networking_port_v2" {
    defaults = {
      all_fixed_ips = ["192.0.2.1"]
    }
  }
}

variables {
  name = "app"
  subnets = {
    main = { cidr = "192.168.10.0/24", allocation_pools = [{ start = "192.168.10.20", end = "192.168.10.250" }] }
    db   = { cidr = "192.168.11.0/24", host_routes = [{ destination = "10.99.0.0/16", nexthop = "192.168.11.1" }] }
  }
  routers = {
    to-transit = {
      external_network_id = "ext-transit"
      internal_subnet     = "main"
      advertise_routes    = ["10.10.0.0/22", "10.10.4.0/22"]
    }
    to-public = {
      external_network_id = "ext-public"
      external_subnet_id  = "ext-public-v4"
      external_ip         = "203.0.113.10"
      internal_subnet     = "main"
      internal_ip         = "192.168.10.1"
    }
  }
}

run "keys_follow_the_input" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = toset(keys(openstack_networking_subnet_v2.this)) == toset(["main", "db"])
    error_message = "Subnets must be keyed by their input keys."
  }

  assert {
    condition     = toset(keys(openstack_networking_router_v2.this)) == toset(["to-transit", "to-public"])
    error_message = "Routers must be keyed by their input keys."
  }

  assert {
    condition     = toset(keys(openstack_networking_subnet_route_v2.this)) == toset(["db/10.99.0.0/16", "main/10.10.0.0/22", "main/10.10.4.0/22"])
    error_message = "Host routes must be keyed by subnet and destination, known at plan time."
  }

  assert {
    condition     = openstack_networking_subnet_v2.this["main"].name == "app-main"
    error_message = "Subnets are named <network>-<key>."
  }

  assert {
    condition     = length(openstack_networking_router_v2.this["to-transit"].external_fixed_ip) == 0 && length(openstack_networking_router_v2.this["to-public"].external_fixed_ip) == 1
    error_message = "external_fixed_ip is set only when external_subnet_id is given."
  }
}

run "first_router_is_the_default_gateway" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    subnets = { main = { cidr = "192.168.10.0/24", gateway_ip = "192.168.10.1" } }
    routers = {
      a-out     = { external_network_id = "ext-public", internal_subnet = "main" }
      b-transit = { external_network_id = "ext-transit", internal_subnet = "main", advertise_routes = ["10.10.0.0/22"] }
    }
  }

  assert {
    condition     = openstack_networking_port_v2.router["a-out"].fixed_ip[0].ip_address == "192.168.10.1"
    error_message = "Without explicit addresses, the first router takes the subnet's gateway address."
  }

  assert {
    condition     = openstack_networking_port_v2.router["b-transit"].fixed_ip[0].ip_address == null
    error_message = "Other routers get an allocated address."
  }
}

run "explicit_default_gateway" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    subnets = { main = { cidr = "192.168.10.0/24", gateway_ip = "192.168.10.1" } }
    routers = {
      a-transit = { external_network_id = "ext-transit", internal_subnet = "main" }
      b-out     = { external_network_id = "ext-public", internal_subnet = "main", default_gateway = true }
    }
  }

  assert {
    condition     = openstack_networking_port_v2.router["b-out"].fixed_ip[0].ip_address == "192.168.10.1" && openstack_networking_port_v2.router["a-transit"].fixed_ip[0].ip_address == null
    error_message = "default_gateway = true picks the gateway router."
  }
}

run "no_automatic_gateway_when_addresses_are_explicit" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = openstack_networking_port_v2.router["to-transit"].fixed_ip[0].ip_address == null && openstack_networking_port_v2.router["to-public"].fixed_ip[0].ip_address == "192.168.10.1"
    error_message = "When a router of the subnet sets internal_ip, nothing is automatic."
  }
}

run "rejects_two_default_gateways" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    routers = {
      a = { external_network_id = "x", internal_subnet = "main", default_gateway = true }
      b = { external_network_id = "y", internal_subnet = "main", default_gateway = true }
    }
  }

  expect_failures = [var.routers]
}

run "rejects_unknown_internal_subnet" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    routers = { bad = { external_network_id = "x", internal_subnet = "nope" } }
  }

  expect_failures = [var.routers]
}

run "rejects_external_ip_without_subnet" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    routers = { bad = { external_network_id = "x", internal_subnet = "main", external_ip = "203.0.113.5" } }
  }

  expect_failures = [var.routers]
}
