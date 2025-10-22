#################################################
# Ports, Volumes, SG, Instances and associations
#################################################

resource "openstack_networking_port_v2" "ports" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for port in instance.ports : {
          instance_name = instance.name
          name          = port.name
          network_name  = port.network_name
          subnet_name   = port.subnet_name
          security_group_ids = [for sg in port.security_group_names : try(
            openstack_networking_secgroup_v2.sec_groups[sg].id,
            data.openstack_networking_secgroup_v2.sec_groups[sg].id
          )]
        }
      ]
    ]) : "${item.instance_name}-${item.name}" => item
  }

  name = each.value.name
  network_id = try(
    data.openstack_networking_network_v2.network[each.value.network_name].id,
    openstack_networking_network_v2.networks[each.value.network_name].id
  )
  fixed_ip {
    subnet_id = try(
      data.openstack_networking_subnet_v2.subnet["${each.value.network_name}-${each.value.subnet_name}"].id,
      openstack_networking_subnet_v2.subnets["${each.value.network_name}-${each.value.subnet_name}"].id
    )
  }

  admin_state_up     = true
  security_group_ids = each.value.security_group_ids
}

locals {
  runcmd_init_volume = {
    for volume in local.host_volume_mountpoint : "${volume.instance_name}-${volume.mountpoint}" => {
      cmds = [
        "sudo mkfs.ext4 ${volume.device}",
        "sudo mkdir -p ${volume.mountpoint}",

        lookup(volume, "username", null) != null ?
        "sudo getent group ${volume.username} || sudo groupadd --system --gid ${volume.gid} ${volume.username}" : "",

        lookup(volume, "username", null) != null ?
        "id -u ${volume.username} >/dev/null 2>&1 || sudo useradd --system --no-create-home --uid ${volume.uid} --gid ${volume.gid} ${volume.username}" : "",

        "echo '${volume.device} ${volume.mountpoint} ext4 defaults 0 0' | sudo tee -a /etc/fstab",
        "sudo mount -a",

        lookup(volume, "uid", null) != null ?
        "sudo chown ${volume.uid}:${volume.gid} ${volume.mountpoint}" : "sudo chown ${var.ssh_user}: ${volume.mountpoint}",
      ]
    } if try(volume.mountpoint, null) != null
  }
}

locals {
  merged_user_data = { for instance in var.instances : instance.name => {

    runcmd = concat(
      # coalesce(local.runcmd_init_volume[instance.name].cmds, []), # Creates cycle dependency instance -> local > instance (in locals{host_volume_mountpoint})
      coalesce(var.cloud_init_common.runcmd, []),
      coalesce(instance.cloud_init.runcmd, [])
    )

    users = concat(
      coalesce(var.cloud_init_common.users, []),
      coalesce(instance.cloud_init.users, [])
    )

    packages = concat(
      coalesce(var.cloud_init_common.packages, []),
      coalesce(instance.cloud_init.packages, [])
    )

    network = concat(
      coalesce(var.cloud_init_common.network, []),
      coalesce(instance.cloud_init.network, [])
    )

    write_files = concat(
      coalesce(var.cloud_init_common.write_files, []),
      coalesce(instance.cloud_init.write_files, [])
    )
  } }
}

locals {
  merged_config = { for key, config in local.merged_user_data : key => {
    runcmd      = config.runcmd
    users       = config.users
    packages    = config.packages
    network     = config.network
    write_files = config.write_files
    system_info = { default_user = { name = "" } }
  } }
}

resource "openstack_compute_instance_v2" "nodes" {
  for_each          = { for instance in var.instances : instance.name => instance }
  name              = each.key
  flavor_name       = each.value.flavor
  image_name        = each.value.image
  availability_zone = each.value.az

  #  user_data = <<EOF
  #    ${templatefile("${path.module}/templates/cloud-init/cloud-init-admin_user.tpl", {
  #        ssh_admin_user = var.ssh_user
  #    })}
  #  EOF

  # user_data = try(yamlencode(local.merged_config[each.value.name]), null)
  user_data = try(
    "#cloud-config\n${yamlencode(local.merged_config[each.value.name])}",
    null
  )

  depends_on = [
    openstack_networking_port_v2.ports,
    openstack_networking_port_v2.provisioning,
    openstack_networking_router_interface_v2.router-port-association
  ]

  dynamic "network" {
    for_each = { for port in each.value.ports : port.name => port }
    content {
      port = openstack_networking_port_v2.ports["${each.value.name}-${network.value.name}"].id
    }
  }

  dynamic "network" {
    for_each = { for key, port in openstack_networking_port_v2.provisioning : port.name => port if key == each.value.name }
    content {
      port = network.value.id
    }
  }

  dynamic "block_device" {
    for_each = each.value.image == null ? [each.value.root_volume] : []
    content {
      uuid                  = each.value.root_volume.create ? openstack_blockstorage_volume_v3.volumes-root[each.value.name].id : data.openstack_blockstorage_volume_v3.volumes-root[each.value.name].id
      source_type           = "volume"
      destination_type      = "volume"
      boot_index            = 0
      delete_on_termination = false
    }
  }

}

resource "openstack_compute_volume_attach_v2" "attachments" {
  depends_on = [
    openstack_compute_instance_v2.nodes,
    openstack_blockstorage_volume_v3.volumes-data
  ]
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for volume in instance.data_volumes : {
          instance_name = instance.name
          volume_name   = volume.name
          create        = volume.create
        }
      ]
    ]) : "${item.instance_name}-${item.volume_name}" => item
  }

  instance_id = openstack_compute_instance_v2.nodes[each.value.instance_name].id
  volume_id   = each.value.create ? openstack_blockstorage_volume_v3.volumes-data["${each.value.instance_name}-${each.value.volume_name}"].id : data.openstack_blockstorage_volume_v3.volumes-data["${each.value.instance_name}-${each.value.volume_name}"].id
}

resource "openstack_networking_floatingip_v2" "instance_floating_ip" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for port in instance.ports : {
          instance_name = instance.name
          pool_name     = port.fip_pool_name
          subnet_name   = port.fip_subnet_name
        } if lookup(port, "fip_pool_name", null) != null
      ]
    ]) : "${item.instance_name}-${item.pool_name}" => item
  }
  pool = each.value.pool_name
  subnet_ids = [try(
    openstack_networking_subnet_v2.subnets["${each.value.pool_name}-${each.value.subnet_name}"].id,
    data.openstack_networking_subnet_v2.subnet["${each.value.pool_name}-${each.value.subnet_name}"].id
  )]
}

resource "openstack_networking_floatingip_associate_v2" "instance_fip_association" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for port in instance.ports : {
          instance_name = instance.name
          port_id       = openstack_networking_port_v2.ports["${instance.name}-${port.name}"].id
          fip_pool_name = port.fip_pool_name
          fip_address   = openstack_networking_floatingip_v2.instance_floating_ip["${instance.name}-${port.fip_pool_name}"].address
        } if lookup(port, "fip_pool_name", null) != null
      ]
    ]) : "${item.instance_name}-${item.fip_pool_name}" => item
  }
  floating_ip = each.value.fip_address
  port_id     = each.value.port_id
  depends_on = [openstack_networking_port_v2.ports,
  openstack_networking_router_interface_v2.router-port-association]
}

resource "openstack_dns_recordset_v2" "instance_fip_recordset" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for port in instance.ports : [
          for record in port.fip_dns_records : {
            instance_name = instance.name
            record_name   = record.name
            zone          = record.zone
            fip_address   = openstack_networking_floatingip_v2.instance_floating_ip["${instance.name}-${port.fip_pool_name}"].address
          }
        ] if lookup(port, "fip_dns_records", null) != null
      ]
    ]) : "${item.record_name}.${item.zone}" => item
  }
  zone_id = try(
    data.openstack_dns_zone_v2.zone[each.value.zone].id,
    openstack_dns_zone_v2.zone[each.value.zone].id
  )
  name        = "${each.value.record_name}.${each.value.zone}"
  description = "DNS record ${each.value.record_name}.${each.value.zone} for ${each.value.instance_name}"
  ttl         = 3000
  type        = "A"
  records     = [each.value.fip_address]
  depends_on  = [openstack_networking_floatingip_associate_v2.instance_fip_association]
}
