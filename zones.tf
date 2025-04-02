##################
# Create Zones
##################

resource "openstack_dns_zone_v2" "zone" {
  for_each = { for zone in var.project_zones : zone.name => zone }

  name        = each.value.name
  email       = each.value.email
  description = each.value.description
  ttl         = each.value.ttl
  type        = "PRIMARY"
}
