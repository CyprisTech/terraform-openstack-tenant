output "id" {
  description = "ID of the load balancer."
  value       = openstack_lb_loadbalancer_v2.this.id
}

output "vip" {
  description = "Virtual IP: { address, port_id }."
  value = {
    address = openstack_lb_loadbalancer_v2.this.vip_address
    port_id = openstack_lb_loadbalancer_v2.this.vip_port_id
  }
}

output "floating_ip" {
  description = "Floating IP of the VIP, or null."
  value       = try(openstack_networking_floatingip_v2.this[0].address, null)
}

output "fqdns" {
  description = "DNS names pointing at the floating IP."
  value       = [for r in openstack_dns_recordset_v2.this : r.name]
}

output "listeners" {
  description = "Listeners keyed like the input: { id, pool_id, port }."
  value = {
    for k, l in openstack_lb_listener_v2.this : k => {
      id      = l.id
      pool_id = openstack_lb_pool_v2.this[k].id
      port    = l.protocol_port
    }
  }
}
