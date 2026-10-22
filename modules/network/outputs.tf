output "id" {
  description = "ID of the network."
  value       = openstack_networking_network_v2.this.id
}

output "name" {
  description = "Name of the network."
  value       = openstack_networking_network_v2.this.name
}

output "subnets" {
  description = "Subnets keyed like the input: { id, cidr, gateway_ip }."
  value = {
    for k, s in openstack_networking_subnet_v2.this : k => {
      id         = s.id
      cidr       = s.cidr
      gateway_ip = s.gateway_ip
    }
  }
}

output "routers" {
  description = "Routers keyed like the input: { id, internal_ip }."
  value = {
    for k, r in openstack_networking_router_v2.this : k => {
      id          = r.id
      internal_ip = openstack_networking_port_v2.router[k].all_fixed_ips[0]
    }
  }
}
