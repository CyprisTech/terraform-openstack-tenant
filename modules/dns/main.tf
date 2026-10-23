locals {
  # The record name is built from the zone name, known at plan time, so a
  # zone ID injected from elsewhere may be unknown without affecting keys.
  records = {
    for k, r in var.records : k => merge(r, {
      zone_name = r.zone != null ? try(var.zones[r.zone].name, "unknown-zone.") : r.zone_name
    })
  }
}

resource "openstack_dns_zone_v2" "this" {
  for_each = var.zones

  name        = each.value.name
  email       = each.value.email
  ttl         = coalesce(each.value.ttl, var.default_ttl)
  description = each.value.description
  type        = "PRIMARY"
  project_id  = var.project_id
}

resource "openstack_dns_recordset_v2" "this" {
  for_each = local.records

  zone_id    = each.value.zone != null ? openstack_dns_zone_v2.this[each.value.zone].id : each.value.zone_id
  name       = each.value.name == "" ? each.value.zone_name : "${each.value.name}.${each.value.zone_name}"
  type       = each.value.type
  records    = each.value.records
  ttl        = coalesce(each.value.ttl, var.default_ttl)
  project_id = var.project_id

  lifecycle {
    precondition {
      condition     = each.value.zone == null || contains(keys(var.zones), coalesce(each.value.zone, "-"))
      error_message = "records.*.zone must be a key of zones."
    }
  }
}
