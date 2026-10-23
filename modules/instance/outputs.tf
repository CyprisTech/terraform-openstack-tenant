output "id" {
  description = "ID of the instance."
  value       = openstack_compute_instance_v2.this.id
}

output "name" {
  description = "Name of the instance."
  value       = openstack_compute_instance_v2.this.name
}

output "az" {
  description = "Availability zone of the instance."
  value       = openstack_compute_instance_v2.this.availability_zone
}

output "labels" {
  description = "Labels of the instance, as given."
  value       = var.labels
}

output "ports" {
  description = "Ports keyed like the input: { id, ip, floating_ip, fqdn }. fqdn is the first DNS name of the port (floating first), or null."
  value = {
    for k, p in openstack_networking_port_v2.this : k => {
      id          = p.id
      ip          = p.all_fixed_ips[0]
      floating_ip = try(openstack_networking_floatingip_v2.this[k].address, null)
      fqdn = try(
        [for rk, r in openstack_dns_recordset_v2.this : r.name if local.dns_records[rk].port == k && local.dns_records[rk].floating][0],
        [for rk, r in openstack_dns_recordset_v2.this : r.name if local.dns_records[rk].port == k][0],
        null,
      )
    }
  }
}

output "volumes" {
  description = "Attached data volumes keyed like the input: { id }."
  value       = { for k in keys(var.volumes) : k => { id = local.volume_ids[k] } }
}
