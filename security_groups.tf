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
  for_each = {
    for r in flatten([
      for sg in var.security_groups : [
        for rule in sg.rules : {
          key     = "${sg.name}-${index(sg.rules, rule)}"
          sg_name = sg.name
          rule    = rule
        }
      ]
    ]) : r.key => r
  }

  security_group_id = openstack_networking_secgroup_v2.sec_groups[each.value.sg_name].id

  direction         = each.value.rule.direction
  ethertype         = each.value.rule.ethertype
  protocol          = try(each.value.rule.protocol, null)
  port_range_min    = try(each.value.rule.port_min, null)
  port_range_max    = try(each.value.rule.port_max, null)
  remote_ip_prefix  = try(each.value.rule.remote_ip_prefix, null)

  depends_on = [openstack_networking_secgroup_v2.sec_groups]
}

resource "openstack_networking_rbac_policy_v2" "common_secgroup_share" {
  for_each = { for sg in var.security_groups : sg.name => sg }

  object_type = "security_group"
  object_id   = openstack_networking_secgroup_v2.sec_groups[each.key].id
  action      = "access_as_shared"
  target_tenant = "*"
}
