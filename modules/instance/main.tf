locals {
  needs_image_lookup = var.image_id == null && var.image != null && var.boot.source == "volume"
  image_id           = local.needs_image_lookup ? data.openstack_images_image_v2.this[0].id : var.image_id

  boot_volume_id = (
    var.boot.source == "volume" ? openstack_blockstorage_volume_v3.boot[0].id :
    var.boot.source == "existing" ? (var.boot.id != null ? var.boot.id : data.openstack_blockstorage_volume_v3.boot[0].id) :
    null
  )

  # Ports are attached in key order: the first key is the primary interface.
  port_keys = sort(keys(var.ports))

  # Extra floating IPs keyed "<port>/<label>"; resources of the primary
  # floating IP keep their "<port>" keys.
  extra_floating_ips = merge([
    for pk, p in var.ports : {
      for lk, f in p.extra_floating_ips : "${pk}/${lk}" => merge(f, { port = pk, label = lk })
    }
  ]...)

  # DNS records keyed by port, kind (fixed or floating), name and zone name:
  # all known at plan time, even when zone IDs come from another module.
  dns_records = merge(
    {
      for item in flatten([
        for pk, p in var.ports : [
          for d in p.dns : merge(d, { port = pk, floating = false, extra = null, label = null })
        ]
      ]) : "${item.port}/fixed/${item.name}@${item.zone_name}" => item
    },
    {
      for item in flatten([
        for pk, p in var.ports : [
          for d in try(p.floating_ip.dns, []) : merge(d, { port = pk, floating = true, extra = null, label = null })
        ]
      ]) : "${item.port}/floating/${item.name}@${item.zone_name}" => item
    },
    # Records on extra floating IPs get their own kind, so the keys of the
    # records above never change when extra floating IPs are added.
    {
      for item in flatten([
        for fk, f in local.extra_floating_ips : [
          for d in f.dns : merge(d, { port = f.port, floating = false, extra = fk, label = f.label })
        ]
      ]) : "${item.port}/extra-floating/${item.label}/${item.name}@${item.zone_name}" => item
    },
  )

  created_volumes  = { for k, v in var.volumes : k => v if v.existing == null }
  existing_volumes = { for k, v in var.volumes : k => v.existing if v.existing != null }
  volume_ids = merge(
    { for k, v in openstack_blockstorage_volume_v3.data : k => v.id },
    { for k, v in local.existing_volumes : k => v.id != null ? v.id : data.openstack_blockstorage_volume_v3.data[k].id },
  )

  metadata = merge(var.metadata, length(var.labels) > 0 ? { labels = join(",", var.labels) } : {})
}

data "openstack_images_image_v2" "this" {
  count       = local.needs_image_lookup ? 1 : 0
  name        = var.image
  most_recent = true
}

data "openstack_blockstorage_volume_v3" "boot" {
  count = var.boot.source == "existing" && var.boot.id == null ? 1 : 0
  name  = var.boot.name
}

data "openstack_blockstorage_volume_v3" "data" {
  for_each = { for k, v in local.existing_volumes : k => v if v.id == null }
  name     = each.value.name
}

resource "openstack_networking_port_v2" "this" {
  for_each = var.ports

  name                  = "${var.name}-${each.key}"
  tenant_id             = var.project_id
  network_id            = each.value.network_id
  port_security_enabled = each.value.port_security_enabled
  security_group_ids    = each.value.port_security_enabled && length(each.value.security_group_ids) > 0 ? each.value.security_group_ids : null

  fixed_ip {
    subnet_id  = each.value.subnet_id
    ip_address = each.value.fixed_ip
  }

  dynamic "allowed_address_pairs" {
    for_each = toset(each.value.allowed_address_pairs)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

resource "openstack_compute_instance_v2" "this" {
  name              = var.name
  availability_zone = var.az
  flavor_name       = var.flavor
  flavor_id         = var.flavor_id
  image_name        = var.boot.source == "image" ? var.image : null
  image_id          = var.boot.source == "image" ? var.image_id : null
  key_pair          = var.key_pair
  user_data         = var.user_data
  metadata          = local.metadata

  # A root volume is always a Cinder volume referenced by ID: either created
  # below with an explicit availability zone, or an existing one.
  dynamic "block_device" {
    for_each = contains(["volume", "existing"], var.boot.source) ? [1] : []
    content {
      source_type           = "volume"
      uuid                  = local.boot_volume_id
      destination_type      = "volume"
      boot_index            = 0
      delete_on_termination = false
    }
  }

  dynamic "network" {
    for_each = local.port_keys
    content {
      port = openstack_networking_port_v2.this[network.value].id
    }
  }

  dynamic "scheduler_hints" {
    for_each = var.server_group_id == null ? [] : [1]
    content {
      group = var.server_group_id
    }
  }

  lifecycle {
    # Terraform does not allow lifecycle rules to depend on variables, so these
    # are fixed: changing the cloud-init data, the image (for example a newer
    # image published under the same name) or the boot device never replaces a
    # running instance by surprise. Replace it explicitly with -replace.
    ignore_changes = [user_data, image_id, image_name, block_device]

    precondition {
      condition     = (var.flavor == null) != (var.flavor_id == null)
      error_message = "Set exactly one of flavor or flavor_id."
    }

    precondition {
      condition     = var.boot.source == "existing" || ((var.image == null) != (var.image_id == null))
      error_message = "Set exactly one of image or image_id (not needed when boot.source is existing)."
    }
  }
}

# The root volume is created here rather than by Nova (block_device with
# source_type = "image"): Nova may not pass its availability zone to Cinder,
# which then falls back to its own default zone and finds no backend (found
# by integration tests). Cinder and Nova zones may also differ, hence boot.az.
resource "openstack_blockstorage_volume_v3" "boot" {
  count = var.boot.source == "volume" ? 1 : 0

  name              = "${var.name}-root"
  size              = var.boot.size
  volume_type       = var.boot.volume_type
  availability_zone = coalesce(var.boot.az, var.az)
  image_id          = local.image_id

  lifecycle {
    # A newer image published under the same name must never recreate the
    # root disk.
    ignore_changes = [image_id]
  }
}

resource "openstack_blockstorage_volume_v3" "data" {
  for_each = local.created_volumes

  name              = "${var.name}-${each.key}"
  size              = each.value.size
  availability_zone = coalesce(each.value.az, var.az)
  volume_type       = each.value.volume_type
}

resource "openstack_compute_volume_attach_v2" "this" {
  for_each = var.volumes

  instance_id = openstack_compute_instance_v2.this.id
  volume_id   = local.volume_ids[each.key]
}

resource "openstack_networking_floatingip_v2" "this" {
  for_each = { for k, p in var.ports : k => p.floating_ip if p.floating_ip != null }

  pool        = each.value.pool
  subnet_id   = each.value.subnet_id
  tenant_id   = var.project_id
  description = "${var.name}-${each.key}"
}

resource "openstack_networking_floatingip_associate_v2" "this" {
  for_each = openstack_networking_floatingip_v2.this

  floating_ip = each.value.address
  port_id     = openstack_networking_port_v2.this[each.key].id

  # The port must be bound to the instance before the association.
  depends_on = [openstack_compute_instance_v2.this]
}

resource "openstack_networking_floatingip_v2" "extra" {
  for_each = local.extra_floating_ips

  pool        = each.value.pool
  subnet_id   = each.value.subnet_id
  tenant_id   = var.project_id
  description = "${var.name}-${each.value.port}-${each.value.label}"
}

resource "openstack_networking_floatingip_associate_v2" "extra" {
  for_each = local.extra_floating_ips

  floating_ip = openstack_networking_floatingip_v2.extra[each.key].address
  port_id     = openstack_networking_port_v2.this[each.value.port].id

  # The port must be bound to the instance before the association.
  depends_on = [openstack_compute_instance_v2.this]
}

resource "openstack_dns_recordset_v2" "this" {
  for_each = local.dns_records

  zone_id = each.value.zone_id
  name    = each.value.name == "" ? each.value.zone_name : "${each.value.name}.${each.value.zone_name}"
  type    = "A"
  ttl     = coalesce(each.value.ttl, var.default_ttl)
  records = [
    each.value.extra != null ? openstack_networking_floatingip_v2.extra[each.value.extra].address :
    each.value.floating ? openstack_networking_floatingip_v2.this[each.value.port].address :
    openstack_networking_port_v2.this[each.value.port].all_fixed_ips[0]
  ]
}
