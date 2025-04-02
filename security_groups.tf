###############################################
# Routers, extra routes, Ports and Association
###############################################

resource "openstack_networking_secgroup_v2" "sec_groups" {
  for_each = { for sg in var.security_groups : sg.name => sg }

  name        = each.value.name
  description = each.value.description

  depends_on = [openstack_networking_quota_v2.quota]
}

resource "openstack_networking_secgroup_rule_v2" "sec_rules" {
  for_each = { for sg in var.security_groups : sg.name => sg }

  security_group_id = openstack_networking_secgroup_v2.sec_groups[each.key].id
  direction         = each.value.rules[0].direction
  ethertype         = each.value.rules[0].ethertype
  protocol          = try(each.value.rules[0].protocol)
  port_range_min    = try(each.value.rules[0].port_min)
  port_range_max    = try(each.value.rules[0].port_max)
  remote_ip_prefix  = each.value.rules[0].remote_ip_prefix

  depends_on = [openstack_networking_secgroup_v2.sec_groups]
}
