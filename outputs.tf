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

output "host_volume_mountpoint" {
  value = local.host_volume_mountpoint
  depends_on = [openstack_compute_instance_v2.nodes]
}

output "cloud_config" {
  value = [for config in local.merged_config: config]
}

output "runcmd_init_volume" {
  value = local.runcmd_init_volume
}

output "instance_details" {
  value = local.instance_details
}

output "private_networks" {
  value = local.private_networks
}
