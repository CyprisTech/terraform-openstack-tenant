output "endpoint" {
  description = "Public address of the application."
  value       = module.tenant.load_balancers["edge"].floating_ip
}

output "bastion" {
  description = "Public address of the bastion."
  value       = module.tenant.instances["bastion"].ports["main"].floating_ip
}

output "inventory" {
  description = "Private addresses grouped by tier label, for the configuration layer (for example an Ansible inventory)."
  value = {
    for tier in ["web", "app", "data"] : tier => [
      for name, i in module.tenant.instances : i.ports["main"].ip if contains(i.labels, tier)
    ]
  }
}
