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

output "private_port_ips" {
  value = {
    for key, port in openstack_networking_port_v2.ports :
    key => port.all_fixed_ips[0]
    if can(regex("-private", port.name))
  }
}

output "admin_port_ips" {
  value = {
    for key, port in openstack_networking_port_v2.provisioning :
    key => port.all_fixed_ips[0]
    if can(regex("-provisioning", port.name))
  }
}
