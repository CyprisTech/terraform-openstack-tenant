# Provider-neutral output contract (docs/adr/0002-output-contract.md): fixed
# shapes keyed like the input, with no OpenStack-specific notion, so that
# upper layers do not need to know which cloud they run on.

output "instances" {
  description = "Instances keyed like the input: { id, az, labels, ports = { <port> = { id, ip, floating_ip, floating_ips, fqdn } } }. floating_ips maps each extra_floating_ips label to its address."
  value = {
    for k, m in module.instance : k => {
      id     = m.id
      az     = m.az
      labels = m.labels
      ports  = { for pk, p in m.ports : pk => { id = p.id, ip = p.ip, floating_ip = p.floating_ip, floating_ips = p.floating_ips, fqdn = p.fqdn } }
    }
  }
}

output "networks" {
  description = "Networks created by the module, keyed like the input: { id, subnets = { <subnet> = { id, cidr } }, routers = { <router> = { id, internal_ip } } }."
  value = {
    for k, m in module.network : k => {
      id      = m.id
      subnets = { for sk, s in m.subnets : sk => { id = s.id, cidr = s.cidr } }
      routers = { for rk, r in m.routers : rk => { id = r.id, internal_ip = r.internal_ip } }
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

output "server_groups" {
  description = "Server groups keyed like the input: { id, policy }."
  value       = { for k, g in openstack_compute_servergroup_v2.this : k => { id = g.id, policy = one(g.policies) } }
}
