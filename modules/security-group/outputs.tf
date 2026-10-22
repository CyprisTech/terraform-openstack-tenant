output "id" {
  description = "ID of the security group."
  value       = openstack_networking_secgroup_v2.this.id
}

output "name" {
  description = "Name of the security group."
  value       = openstack_networking_secgroup_v2.this.name
}

output "rule_ids" {
  description = "IDs of the rules, keyed like the input."
  value       = { for k, r in openstack_networking_secgroup_rule_v2.this : k => r.id }
}
