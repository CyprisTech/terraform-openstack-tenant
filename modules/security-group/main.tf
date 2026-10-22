resource "openstack_networking_secgroup_v2" "this" {
  name                 = var.name
  description          = var.description
  tenant_id            = var.project_id
  delete_default_rules = var.delete_default_rules
}

resource "openstack_networking_secgroup_rule_v2" "this" {
  for_each = var.rules

  security_group_id = openstack_networking_secgroup_v2.this.id
  tenant_id         = var.project_id
  description       = each.value.description
  direction         = each.value.direction
  ethertype         = each.value.ethertype
  protocol          = each.value.protocol
  port_range_min    = each.value.port_min
  port_range_max    = each.value.port_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  remote_group_id   = each.value.remote_group_id == "self" ? openstack_networking_secgroup_v2.this.id : each.value.remote_group_id
}
