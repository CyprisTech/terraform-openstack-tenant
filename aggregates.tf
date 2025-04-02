resource "openstack_compute_aggregate_v2" "aggregate" {
  for_each = { for aggregate in var.compute_aggregates : aggregate.name => aggregate }

  name     = each.value.name
  region   = var.region
  zone     = each.value.zone
  hosts    = each.value.hosts
}

