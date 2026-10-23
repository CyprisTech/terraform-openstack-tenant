mock_provider "openstack" {}

variables {
  zones = {
    app = { name = "app.example.org.", email = "hostmaster@example.org" }
  }
  records = {
    apex = { zone = "app", name = "", type = "A", records = ["192.0.2.1"] }
    mail = { zone = "app", name = "", type = "MX", records = ["10 mail.example.org."], ttl = 600 }
    svc  = { zone_id = "zone-shared", zone_name = "svc.example.org.", name = "api", type = "CNAME", records = ["api.app.example.org."] }
  }
}

run "zones_and_records" {
  command = plan

  module {
    source = "./modules/dns"
  }

  assert {
    condition     = toset(keys(openstack_dns_recordset_v2.this)) == toset(["apex", "mail", "svc"])
    error_message = "Records are keyed by their input keys."
  }

  assert {
    condition     = openstack_dns_recordset_v2.this["apex"].name == "app.example.org." && openstack_dns_recordset_v2.this["svc"].name == "api.svc.example.org."
    error_message = "Record names are built from the zone name."
  }

  assert {
    condition     = openstack_dns_recordset_v2.this["svc"].zone_id == "zone-shared" && openstack_dns_recordset_v2.this["mail"].ttl == 600 && openstack_dns_recordset_v2.this["apex"].ttl == 3000
    error_message = "External zones use the given ID; TTL falls back to default_ttl."
  }
}

run "zone_created_for_a_project" {
  command = plan

  module {
    source = "./modules/dns"
  }

  variables {
    project_id = "tenant-project"
  }

  assert {
    condition     = openstack_dns_zone_v2.this["app"].project_id == "tenant-project"
    error_message = "With project_id, zones are created for that project."
  }
}

run "rejects_record_without_zone" {
  command = plan

  module {
    source = "./modules/dns"
  }

  variables {
    records = { bad = { name = "x", type = "A", records = ["192.0.2.1"] } }
  }

  expect_failures = [var.records]
}

run "rejects_unknown_zone_key" {
  command = plan

  module {
    source = "./modules/dns"
  }

  variables {
    records = { bad = { zone = "nope", name = "x", type = "A", records = ["192.0.2.1"] } }
  }

  expect_failures = [openstack_dns_recordset_v2.this]
}
