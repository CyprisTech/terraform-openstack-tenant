###########################################################
#
# Automated creation of admin port (provisioning) 
# according to the flag enable_admin_port = true | false
#
###########################################################

resource "openstack_networking_port_v2" "provisioning" {
  for_each = {
    for instance in var.instances : instance.name => {
      instance_name = instance.name
      name          = "${instance.name}-provisioning"

      network_id = try(
        data.openstack_networking_network_v2.network["provisioning"].id,
        openstack_networking_network_v2.networks["provisioning"].id
      )
      subnet_id = try(
        data.openstack_networking_subnet_v2.subnet["provisioning-provisioning"].id,
        openstack_networking_subnet_v2.subnets["provisioning-provisioning"].id
      )

      security_group_ids = concat(
        [
          try(
            openstack_networking_secgroup_v2.sec_groups["admin-ssh-ingress"].id,
            data.openstack_networking_secgroup_v2.sec_groups["admin-ssh-ingress"].id
          )
        ],
        instance.admin_port_egress ? [
          try(
            openstack_networking_secgroup_v2.sec_groups["admin-ssh-egress"].id,
            data.openstack_networking_secgroup_v2.sec_groups["admin-ssh-egress"].id
          )
        ] : []
      )
    } if instance.enable_admin_port
  }

  name       = each.value.name
  network_id = each.value.network_id
  fixed_ip {
    subnet_id = each.value.subnet_id
  }

  admin_state_up     = true
  security_group_ids = each.value.security_group_ids
}
