mock_provider "openstack" {
  mock_resource "openstack_networking_floatingip_v2" {
    defaults = {
      address = "203.0.113.20"
    }
  }
}

variables {
  name = "edge"
  vip  = { subnet_id = "sub-edge" }
  floating_ip = {
    pool = "public"
    dns  = [{ name = "", zone_id = "zone-1", zone_name = "example.org." }, { name = "www", zone_id = "zone-1", zone_name = "example.org." }]
  }
  listeners = {
    http = {
      protocol       = "HTTP"
      port           = 80
      insert_headers = { "X-Forwarded-For" = "true" }
      pool = {
        protocol = "HTTP"
        members = {
          "proxy-1.main" = { address = "192.168.40.11" }
          "proxy-2.main" = { address = "192.168.40.12" }
        }
        monitor = { type = "HTTP", url_path = "/ping" }
      }
    }
    https = {
      protocol = "TCP"
      port     = 443
      pool = {
        protocol    = "PROXY"
        member_port = 8443
        members = {
          "proxy-1.main" = { address = "192.168.40.11" }
          "proxy-2.main" = { address = "192.168.40.12", port = 9443 }
        }
        monitor = { type = "TCP" }
      }
    }
  }
}

run "keys_follow_the_input" {
  command = plan

  module {
    source = "./modules/loadbalancer"
  }

  assert {
    condition     = toset(keys(openstack_lb_listener_v2.this)) == toset(["http", "https"]) && toset(keys(openstack_lb_pool_v2.this)) == toset(["http", "https"])
    error_message = "Listeners and pools are keyed by listener key."
  }

  assert {
    condition     = toset(keys(openstack_lb_member_v2.this)) == toset(["http/proxy-1.main", "http/proxy-2.main", "https/proxy-1.main", "https/proxy-2.main"])
    error_message = "Members are keyed by listener and member keys."
  }

  assert {
    condition     = openstack_lb_member_v2.this["http/proxy-1.main"].protocol_port == 80 && openstack_lb_member_v2.this["https/proxy-1.main"].protocol_port == 8443 && openstack_lb_member_v2.this["https/proxy-2.main"].protocol_port == 9443
    error_message = "Member port: member, then pool member_port, then listener port."
  }

  assert {
    condition     = openstack_lb_monitor_v2.this["http"].url_path == "/ping" && openstack_lb_monitor_v2.this["https"].type == "TCP"
    error_message = "Monitors are created per pool with their own settings."
  }

  assert {
    condition     = toset(keys(openstack_dns_recordset_v2.this)) == toset(["@example.org.", "www@example.org."]) && openstack_dns_recordset_v2.this["@example.org."].name == "example.org."
    error_message = "DNS records on the floating IP are keyed by name and zone name."
  }
}

run "no_floating_ip" {
  command = plan

  module {
    source = "./modules/loadbalancer"
  }

  variables {
    floating_ip = null
  }

  assert {
    condition     = length(openstack_networking_floatingip_v2.this) == 0 && length(openstack_dns_recordset_v2.this) == 0
    error_message = "No floating IP and no DNS records when floating_ip is null."
  }
}

run "rejects_headers_on_tcp" {
  command = plan

  module {
    source = "./modules/loadbalancer"
  }

  variables {
    listeners = { bad = { protocol = "TCP", port = 443, insert_headers = { "X-Forwarded-For" = "true" }, pool = { protocol = "TCP", members = {} } } }
  }

  expect_failures = [var.listeners]
}

run "rejects_unknown_monitor_type" {
  command = plan

  module {
    source = "./modules/loadbalancer"
  }

  variables {
    listeners = { bad = { protocol = "TCP", port = 443, pool = { protocol = "TCP", members = {}, monitor = { type = "ICMP" } } } }
  }

  expect_failures = [var.listeners]
}
