output "zones" {
  description = "Zones keyed like the input: { id, name }."
  value       = { for k, z in openstack_dns_zone_v2.this : k => { id = z.id, name = z.name } }
}

output "records" {
  description = "Record sets keyed like the input: { id, fqdn }."
  value       = { for k, r in openstack_dns_recordset_v2.this : k => { id = r.id, fqdn = r.name } }
}
