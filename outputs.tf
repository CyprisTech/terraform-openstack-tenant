# Provider-neutral output contract (draft, see docs/tenant-model.md): fixed
# shapes keyed like the input, with no OpenStack-specific notion, so that
# upper layers do not need to know which cloud they run on.

output "instances" {
  description = "Instances keyed like the input: { id, az, labels, ports = { <port> = { ip, floating_ip, fqdn } } }."
  value = {
    for k, m in module.instance : k => {
      id     = m.id
      az     = m.az
      labels = m.labels
      ports  = { for pk, p in m.ports : pk => { ip = p.ip, floating_ip = p.floating_ip, fqdn = p.fqdn } }
    }
  }
}

output "networks" {
  description = "Networks created by the module, keyed like the input: { id, subnets = { <subnet> = { id, cidr } } }."
  value = {
    for k, m in module.network : k => {
      id      = m.id
      subnets = { for sk, s in m.subnets : sk => { id = s.id, cidr = s.cidr } }
    }
  }
}

output "security_groups" {
  description = "Security groups created by the module, keyed like the input: { id }."
  value       = { for k, m in module.security_group : k => { id = m.id } }
}

output "load_balancers" {
  description = "Load balancers keyed like the input: { id, vip, floating_ip, fqdns }."
  value = {
    for k, m in module.loadbalancer : k => {
      id          = m.id
      vip         = m.vip.address
      floating_ip = m.floating_ip
      fqdns       = m.fqdns
    }
  }
}

output "dns_zones" {
  description = "DNS zones created by the module, keyed like the input: { id, name }."
  value       = module.dns.zones
}
