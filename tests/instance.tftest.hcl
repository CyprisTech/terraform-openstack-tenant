mock_provider "openstack" {
  # Values computed by OpenStack: unknown at plan time on a real cloud, the
  # mock needs concrete ones.
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
  mock_data "openstack_images_image_v2" {
    defaults = {
      id = "00000000-0000-0000-0000-000000000001"
    }
  }
  mock_data "openstack_blockstorage_volume_v3" {
    defaults = {
      id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

variables {
  name   = "web-1"
  az     = "nova"
  flavor = "m1.small"
  image  = "ubuntu-24.04"
  ports = {
    main = {
      network_id         = "net-app"
      subnet_id          = "sub-app"
      security_group_ids = ["sg-web"]
      floating_ip = {
        pool = "public"
        dns  = [{ name = "www", zone_id = "zone-1", zone_name = "example.org." }, { name = "", zone_id = "zone-1", zone_name = "example.org." }]
      }
      dns = [{ name = "web-1", zone_id = "zone-2", zone_name = "internal.example.org." }]
    }
    mgmt = {
      network_id         = "net-mgmt"
      subnet_id          = "sub-mgmt"
      security_group_ids = ["sg-ssh"]
    }
  }
  volumes = {
    data = { size = 20 }
    keep = { existing = { name = "web-1-keep" } }
  }
  labels = ["edge", "web"]
}

run "keys_follow_the_input" {
  command = plan

  module {
    source = "./modules/instance"
  }

  assert {
    condition     = toset(keys(openstack_networking_port_v2.this)) == toset(["main", "mgmt"])
    error_message = "Ports must be keyed by their input keys."
  }

  assert {
    condition     = toset(keys(openstack_networking_floatingip_v2.this)) == toset(["main"])
    error_message = "Only ports with floating_ip get one."
  }

  assert {
    condition = toset(keys(openstack_dns_recordset_v2.this)) == toset([
      "main/floating/www@example.org.",
      "main/floating/@example.org.",
      "main/fixed/web-1@internal.example.org.",
    ])
    error_message = "DNS records must be keyed by port, kind, name and zone name."
  }

  assert {
    condition     = openstack_dns_recordset_v2.this["main/floating/@example.org."].name == "example.org."
    error_message = "An empty name is the zone apex."
  }

  assert {
    condition     = toset(keys(openstack_blockstorage_volume_v3.data)) == toset(["data"]) && toset(keys(openstack_compute_volume_attach_v2.this)) == toset(["data", "keep"])
    error_message = "Only volumes with a size are created; all are attached."
  }

  assert {
    condition     = openstack_compute_instance_v2.this.metadata["labels"] == "edge,web"
    error_message = "Labels are exposed in metadata."
  }

  assert {
    condition     = length(openstack_compute_instance_v2.this.block_device) == 0 && openstack_compute_instance_v2.this.image_name == "ubuntu-24.04"
    error_message = "Default boot uses the image directly."
  }
}

run "boot_from_new_volume" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    boot = { source = "volume", size = 30 }
  }

  assert {
    condition     = length(openstack_blockstorage_volume_v3.boot) == 1 && openstack_blockstorage_volume_v3.boot[0].availability_zone == "nova" && openstack_compute_instance_v2.this.block_device[0].source_type == "volume"
    error_message = "A new root volume is created by the module in an explicit availability zone, then booted from."
  }
}

run "boot_volume_in_another_zone" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    boot = { source = "volume", size = 30, az = "cinder-az" }
  }

  assert {
    condition     = openstack_blockstorage_volume_v3.boot[0].availability_zone == "cinder-az" && openstack_compute_instance_v2.this.availability_zone == "nova"
    error_message = "The root volume may live in a Cinder zone different from the Nova zone."
  }
}

run "boot_from_existing_volume" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    image = null
    boot  = { source = "existing", id = "vol-root" }
  }

  assert {
    condition     = openstack_compute_instance_v2.this.block_device[0].uuid == "vol-root" && !openstack_compute_instance_v2.this.block_device[0].delete_on_termination
    error_message = "An existing root volume is used and kept."
  }
}

run "rejects_flavor_and_flavor_id" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    flavor_id = "f-1"
  }

  expect_failures = [openstack_compute_instance_v2.this]
}

run "rejects_volume_with_size_and_existing" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    volumes = { bad = { size = 10, existing = { id = "v" } } }
  }

  expect_failures = [var.volumes]
}

run "rejects_security_groups_without_port_security" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    ports = { main = { network_id = "n", subnet_id = "s", port_security_enabled = false, security_group_ids = ["sg"] } }
  }

  expect_failures = [var.ports]
}

run "rejects_zone_name_without_dot" {
  command = plan

  module {
    source = "./modules/instance"
  }

  variables {
    ports = { main = { network_id = "n", subnet_id = "s", dns = [{ name = "a", zone_id = "z", zone_name = "example.org" }] } }
  }

  expect_failures = [var.ports]
}
