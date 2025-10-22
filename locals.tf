locals {
  instance_admin_ip_address = {
    for item in flatten([
      for instance in var.instances : [
        for port in openstack_networking_port_v2.provisioning : {
          ip_address    = port.all_fixed_ips[0]
          instance_name = instance.name
        } if openstack_compute_instance_v2.nodes[instance.name].id == port.device_id && can(regex("-provisioning", port.name))
      ]
    ]) : item.instance_name => item
  }

  instance_private_ip_address = {
    for item in flatten([
      for instance in var.instances : [
        for port in openstack_networking_port_v2.ports : {
          ip_address    = port.all_fixed_ips[0]
          instance_name = instance.name
        } if openstack_compute_instance_v2.nodes[instance.name].id == port.device_id && can(regex("-private$", port.name))
      ]
    ]) : item.instance_name => item
  }
}

locals {
  host_volume_mountpoint = [
    for item in flatten([
      for instance in var.instances : [
        #for port in instance.ports : [
        for volume in instance.data_volumes : merge({
          instance_name           = instance.name
          ip_address_private_port = local.instance_private_ip_address[instance.name].ip_address
          mountpoint              = volume.mountpoint
          device                  = openstack_compute_volume_attach_v2.attachments["${instance.name}-${volume.name}"].device
          # volume_id = openstack_blockstorage_volume_v3.volumes-data["${instance.name}-${volume.name}"].id
          # instance_id = openstack_compute_instance_v2.nodes["${instance.name}"].id
          },
          volume.uid != null ? { uid = volume.uid } : {},
          volume.gid != null ? { gid = volume.gid } : {},
          volume.username != null ? { username = volume.username } : {},
          #(try(openstack_networking_floatingip_associate_v2.instance_fip_association["${instance.name}-${port.fip_pool_name}"], null) != null) ? { ip_address_fip = openstack_networking_floatingip_associate_v2.instance_fip_association["${instance.name}-${port.fip_pool_name}"].floating_ip } : {},
          try(local.instance_admin_ip_address[instance.name], null) != null ? { ip_address_admin_port = local.instance_admin_ip_address[instance.name].ip_address } : {}
        ) if volume.create && try(volume.mountpoint, null) != null
        #]
      ]
    ]) : item
  ]

  host_bind_mounts = [
    for item in flatten([
      for instance in var.instances : [
        for bm in instance.bind_mounts : merge({
          instance_name           = instance.name
          ip_address_private_port = local.instance_private_ip_address[instance.name].ip_address
          username                = bm.username
          uid                     = bm.uid
          gid                     = bm.gid
          path                    = bm.path
          },
          try(bm.conf_src_file, null) != null ? { conf_src_file = bm.conf_template_file } : {},
          try(bm.conf_template_file, null) != null ? { conf_template_file = bm.conf_template_file } : {},
          try(bm.template_vars, null) != null ? { template_vars = bm.template_vars } : {},
          try(local.instance_admin_ip_address[instance.name], null) != null ? { ip_address_admin_port = local.instance_admin_ip_address[instance.name].ip_address } : {}
        )
      ] if try(instance.bind_mounts, null) != null
    ]) : item
  ]
}


locals {
  instance_details = [
    for instance in var.instances : merge({
      hostname           = instance.name
      hostname_sanitized = replace(instance.name, "_", "-")
      labels             = instance.instance_labels
      availability_zone  = openstack_compute_instance_v2.nodes["${instance.name}"].availability_zone
      #volume_availability_zone = try(openstack_blockstorage_volume_v3.volumes-root["${instance.name}"].availability_zone, data.openstack_blockstorage_volume_v3.volumes-root["${instance.name}"].availability_zone)
      volume_availability_zone = try(openstack_blockstorage_volume_v3.volumes-root["${instance.name}"].availability_zone, instance.root_volume.az, instance.az)
      ip_address_private       = local.instance_private_ip_address[instance.name].ip_address
      #instance_id              = openstack_compute_instance_v2.nodes["${instance.name}"].id
      },
      can(openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name]) ? { ip_address_fip = openstack_networking_floatingip_associate_v2.instance_fip_association[instance.name].floating_ip } : {},
      try(local.instance_admin_ip_address[instance.name], null) != null ? { ip_address_admin = local.instance_admin_ip_address[instance.name].ip_address } : {}
    )
  ]
}


locals {
  private_networks = [
    for item in flatten([
      for network in var.networks : [
        for subnet in network.subnets : {
          net_name    = network.name
          net_id      = openstack_networking_network_v2.networks[network.name].id
          subnet_name = subnet.name
          subnet_id   = openstack_networking_subnet_v2.subnets["${network.name}-${subnet.name}"].id
        }
      ]
    ]) : item
  ]
}
