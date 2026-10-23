output "rendered" {
  description = "Cloud-config document to pass as user_data."
  value       = "#cloud-config\n${yamlencode(local.config)}"

  precondition {
    condition     = alltrue([for b in values(var.bind_mounts) : contains(keys(var.disks), b.disk)])
    error_message = "Each bind_mounts.*.disk must be a key of disks."
  }
}

output "config" {
  description = "The cloud-config as an object, for inspection or further merging."
  value       = local.config
}
