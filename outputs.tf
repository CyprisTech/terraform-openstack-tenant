output "users_created" {
  value = { for k, v in openstack_identity_user_v3.users : k => v.id }
}

output "flavors_created" {
  value = { for k, v in openstack_compute_flavor_v2.flavors : k => v.id }
}

output "security_groups_created" {
  value = { for k, v in openstack_networking_secgroup_v2.sec_groups : k => v.id }
}


output "network_ids" {
  value = [for net in openstack_networking_network_v2.networks : {
    network_id = net.id
    network_name = net.name
  }]
}

output "subnet_ids" {
  value = [for subnet in openstack_networking_subnet_v2.subnets : {
    subnet_id = subnet.id
    subnet_name = subnet.name
  }]
}

output "volumes_devices" {
  value = {
    for key, attch in openstack_compute_volume_attach_v2.attachments :
    key => attch.device
  }
}

locals {
  instance_admin_ip_address = {
    for item in flatten([
      for instance in var.instances :  [
        for port in openstack_networking_port_v2.provisioning : {
          ip_address      = port.all_fixed_ips[0]
          instance_name   = instance.name
        } if openstack_compute_instance_v2.nodes[instance.name].id == port.device_id && can(regex("-provisioning", port.name))
      ]
    ]): item.instance_name => item
  }

  instance_private_ip_address = {
    for item in flatten([
      for instance in var.instances :  [
        for port in openstack_networking_port_v2.ports : {
          ip_address      = port.all_fixed_ips[0]
          instance_name   = instance.name
        } if openstack_compute_instance_v2.nodes[instance.name].id == port.device_id && can(regex("-private", port.name))
      ]
    ]): item.instance_name => item
  }
}

output "host_volume_mountpoint" {

  value = [
    for item in flatten([
      for instance in var.instances : [
        for volume in instance.data_volumes : merge ({
            instance_name = instance.name
            ip_address_private_port = local.instance_private_ip_address[instance.name].ip_address
            mountpoint = volume.mountpoint
            device = openstack_compute_volume_attach_v2.attachments["${instance.name}-${volume.name}"].device
            # volume_id = openstack_blockstorage_volume_v3.volumes-data["${instance.name}-${volume.name}"].id
            # instance_id = openstack_compute_instance_v2.nodes["${instance.name}"].id
          },
          volume.uid != null ? { uid = volume.uid } : {},
          volume.gid != null ? { gid = volume.gid } : {},
          volume.username != null ? { username = volume.username } : {},
          openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name] != null ? { ip_address_fip = openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name].floating_ip } : {},
          try(local.instance_admin_ip_address[instance.name], null) != null ? { ip_address_admin_port = local.instance_admin_ip_address[instance.name].ip_address } : {}
        ) if try(volume.mountpoint, null) != null
      ]
    ]): item
  ]

  depends_on = [openstack_compute_instance_v2.nodes]
}

output "cloud_config" {
  value = [for config in local.merged_config: config]
}
