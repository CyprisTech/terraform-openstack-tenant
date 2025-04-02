locals { 
  instance_provisioning_ip = {
    for item in flatten([
      for instance in var.instances :  [
        for port in openstack_networking_port_v2.provisioning : {
          ip_address      = port.all_fixed_ips[0]
          instance_name   = instance.name
        } if openstack_compute_instance_v2.nodes[instance.name].id == port.device_id && can(regex("-provisioning", port.name))
      ]
    ]): item.instance_name => item
  }

  instance_private_ip = {
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
