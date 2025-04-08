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

locals {
  host_volume_mountpoint = [
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
}


locals {
  instance_details = [
    for instance in var.instances : merge ({
        instance_name = instance.name
        instance_labels = instance.instance_labels
        ip_address_private = local.instance_private_ip_address[instance.name].ip_address
        #instance_id = openstack_compute_instance_v2.nodes["${instance.name}"].id
      },
      openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name] != null ? { ip_address_fip = openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name].floating_ip } : {},
      try(local.instance_admin_ip_address[instance.name], null) != null ? { ip_address_admin = local.instance_admin_ip_address[instance.name].ip_address } : {}
    )
  ]
}


locals {
  private_networks = [
    for item in flatten([
      for network in var.networks : [
        for subnet in network.subnets : {
          net_name = network.name
          net_id = openstack_networking_network_v2.networks[network.name].id
          subnet_name = subnet.name
          subnet_id = openstack_networking_subnet_v2.subnets["${network.name}-${subnet.name}"]
        }
      ]
    ]) : item
  ]
}
