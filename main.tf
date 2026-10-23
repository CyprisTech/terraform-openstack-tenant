locals {
  t  = var.tenant
  ex = var.tenant.existing

  # ---------------------------------------------------------------------------
  # Adopted objects. Every map below is keyed by input keys only, so keys are
  # known at plan time even when IDs come from another module in the same apply.
  # ---------------------------------------------------------------------------

  existing_subnets = merge([
    for nk, n in local.ex.networks : {
      for sk, s in n.subnets : "${nk}/${sk}" => merge(s, { network = nk })
    }
  ]...)

  # ---------------------------------------------------------------------------
  # Key -> ID (and name) resolution, for adopted and created objects alike.
  # ---------------------------------------------------------------------------

  # Adopted objects only: used by the network and security group modules,
  # which cannot depend on their own outputs.
  existing_network_ids        = { for k, n in local.ex.networks : k => data.openstack_networking_network_v2.existing[k].id }
  existing_subnet_ids         = { for k, s in local.existing_subnets : k => s.id != null ? s.id : data.openstack_networking_subnet_v2.existing[k].id }
  existing_security_group_ids = { for k, g in local.ex.security_groups : k => g.id != null ? g.id : data.openstack_networking_secgroup_v2.existing[k].id }

  network_ids = merge(
    local.existing_network_ids,
    { for k, m in module.network : k => m.id },
  )

  # Floating IP pools are external networks given by name to Neutron.
  network_names = { for k, n in local.ex.networks : k => data.openstack_networking_network_v2.existing[k].name }

  subnet_ids = merge(
    local.existing_subnet_ids,
    merge([
      for nk, n in local.t.networks : {
        for sk, s in n.subnets : "${nk}/${sk}" => module.network[nk].subnets[sk].id
      }
    ]...),
  )

  # Subnet keys of every network, to pick a default subnet when none is given.
  subnet_keys = merge(
    { for k, n in local.ex.networks : k => sort(keys(n.subnets)) },
    { for k, n in local.t.networks : k => sort(keys(n.subnets)) },
  )

  security_group_ids = merge(
    local.existing_security_group_ids,
    { for k, m in module.security_group : k => m.id },
  )

  zone_ids = merge(
    { for k, z in local.ex.dns_zones : k => z.id != null ? z.id : data.openstack_dns_zone_v2.existing[k].id },
    { for k, z in module.dns.zones : k => z.id },
  )

  zone_names = merge(
    { for k, z in local.ex.dns_zones : k => z.name },
    { for k, z in local.t.dns.zones : k => z.name },
  )

  # ---------------------------------------------------------------------------
  # Security group rules. A rule referencing *another local* group cannot be
  # passed to the module instance of its own group (that would make module
  # instances depend on each other), so those rules are created here.
  # ---------------------------------------------------------------------------

  cross_group_rules = merge([
    for gk, g in local.t.security_groups : {
      for rk, r in g.rules : "${gk}/${rk}" => merge(r, { group = gk })
      if r.remote_group != null && r.remote_group != gk && contains(keys(local.t.security_groups), coalesce(r.remote_group, "-"))
    }
  ]...)

  # ---------------------------------------------------------------------------
  # Instances: ports, with the optional management port under the reserved
  # key "management".
  # ---------------------------------------------------------------------------

  instance_ports = {
    for ik, i in local.t.instances : ik => merge(
      { for pk, p in i.ports : pk => merge(p, { security_groups = p.security_groups }) },
      i.management_port ? {
        management = {
          network         = local.t.management_port.network
          subnet          = coalesce(local.t.management_port.subnet, local.subnet_keys[local.t.management_port.network][0])
          fixed_ip        = null
          security_groups = concat(local.t.management_port.security_groups, i.management_egress ? local.t.management_port.egress_security_groups : [])
          floating_ip     = null
          dns             = []
        }
      } : {},
    )
  }
}

# -----------------------------------------------------------------------------
# Lookups for objects adopted by name (and networks by ID, to learn the name
# Neutron expects for floating IP pools).
# -----------------------------------------------------------------------------

data "openstack_networking_network_v2" "existing" {
  for_each = local.ex.networks

  name       = each.value.name
  network_id = each.value.id
}

data "openstack_networking_subnet_v2" "existing" {
  for_each = { for k, s in local.existing_subnets : k => s if s.id == null }

  name       = each.value.name
  network_id = data.openstack_networking_network_v2.existing[each.value.network].id
}

data "openstack_networking_secgroup_v2" "existing" {
  for_each = { for k, g in local.ex.security_groups : k => g if g.id == null }

  name = each.value.name
}

data "openstack_dns_zone_v2" "existing" {
  for_each = { for k, z in local.ex.dns_zones : k => z if z.id == null }

  name = each.value.name
}

# -----------------------------------------------------------------------------
# Building blocks
# -----------------------------------------------------------------------------

module "network" {
  source   = "./modules/network"
  for_each = local.t.networks

  name                    = coalesce(each.value.name, each.key)
  mtu                     = each.value.mtu
  admin_state_up          = each.value.admin_state_up
  availability_zone_hints = each.value.availability_zone_hints
  subnets                 = each.value.subnets

  routers = {
    for rk, r in each.value.routers : rk => {
      external_network_id     = local.existing_network_ids[r.external_network]
      external_subnet_id      = r.external_subnet == null ? null : local.existing_subnet_ids["${r.external_network}/${r.external_subnet}"]
      external_ip             = r.external_ip
      internal_subnet         = r.internal_subnet
      internal_ip             = r.internal_ip
      advertise_routes        = r.advertise_routes
      admin_state_up          = r.admin_state_up
      availability_zone_hints = r.availability_zone_hints
    }
  }
}

module "security_group" {
  source   = "./modules/security-group"
  for_each = local.t.security_groups

  name        = each.key
  description = each.value.description

  rules = {
    for rk, r in each.value.rules : rk => {
      direction        = r.direction
      ethertype        = r.ethertype
      protocol         = r.protocol
      port_min         = r.port_min
      port_max         = r.port_max
      remote_ip_prefix = r.remote_ip_prefix
      remote_group_id = (
        r.remote_group == null ? null :
        r.remote_group == each.key ? "self" :
        local.existing_security_group_ids[r.remote_group]
      )
      description = ""
    }
    if !contains(keys(local.cross_group_rules), "${each.key}/${rk}")
  }
}

resource "openstack_networking_secgroup_rule_v2" "cross_group" {
  for_each = local.cross_group_rules

  security_group_id = module.security_group[each.value.group].id
  direction         = each.value.direction
  ethertype         = each.value.ethertype
  protocol          = each.value.protocol
  port_range_min    = each.value.port_min
  port_range_max    = each.value.port_max
  remote_group_id   = module.security_group[each.value.remote_group].id
}

module "dns" {
  source = "./modules/dns"

  zones       = local.t.dns.zones
  default_ttl = local.t.defaults.ttl

  records = {
    for k, r in local.t.dns.records : k => {
      zone      = contains(keys(local.t.dns.zones), r.zone) ? r.zone : null
      zone_id   = contains(keys(local.t.dns.zones), r.zone) ? null : local.zone_ids[r.zone]
      zone_name = contains(keys(local.t.dns.zones), r.zone) ? null : local.zone_names[r.zone]
      name      = r.name
      type      = r.type
      records   = r.records
      ttl       = r.ttl
    }
  }
}

module "instance" {
  source   = "./modules/instance"
  for_each = local.t.instances

  name        = each.key
  az          = each.value.az
  flavor      = each.value.flavor
  flavor_id   = each.value.flavor_id
  image       = each.value.image
  image_id    = each.value.image_id
  boot        = each.value.boot
  volumes     = each.value.volumes
  user_data   = each.value.user_data
  labels      = each.value.labels
  metadata    = each.value.metadata
  default_ttl = local.t.defaults.ttl

  ports = {
    for pk, p in local.instance_ports[each.key] : pk => {
      network_id         = local.network_ids[p.network]
      subnet_id          = local.subnet_ids["${p.network}/${p.subnet}"]
      fixed_ip           = p.fixed_ip
      security_group_ids = [for g in p.security_groups : local.security_group_ids[g]]
      floating_ip = p.floating_ip == null ? null : {
        pool      = local.network_names[p.floating_ip.pool]
        subnet_id = p.floating_ip.subnet == null ? null : local.subnet_ids["${p.floating_ip.pool}/${p.floating_ip.subnet}"]
        dns       = [for d in p.floating_ip.dns : { name = d.name, zone_id = local.zone_ids[d.zone], zone_name = local.zone_names[d.zone] }]
      }
      dns = [for d in p.dns : { name = d.name, zone_id = local.zone_ids[d.zone], zone_name = local.zone_names[d.zone] }]
    }
  }
}

module "loadbalancer" {
  source   = "./modules/loadbalancer"
  for_each = local.t.load_balancers

  name               = each.key
  vip                = { subnet_id = local.subnet_ids["${each.value.vip.network}/${each.value.vip.subnet}"], address = each.value.vip.ip }
  flavor_id          = each.value.flavor_id
  availability_zone  = each.value.availability_zone
  security_group_ids = [for g in each.value.security_groups : local.security_group_ids[g]]
  default_ttl        = local.t.defaults.ttl

  floating_ip = each.value.floating_ip == null ? null : {
    pool      = local.network_names[each.value.floating_ip.pool]
    subnet_id = each.value.floating_ip.subnet == null ? null : local.subnet_ids["${each.value.floating_ip.pool}/${each.value.floating_ip.subnet}"]
    dns       = [for d in each.value.floating_ip.dns : { name = d.name, zone_id = local.zone_ids[d.zone], zone_name = local.zone_names[d.zone] }]
  }

  listeners = {
    for lk, l in each.value.listeners : lk => {
      protocol      = l.protocol
      port          = l.port
      allowed_cidrs = l.allowed_cidrs
      timeouts = {
        client_data    = lookup(l.timeouts, "client_data", null)
        member_connect = lookup(l.timeouts, "member_connect", null)
        member_data    = lookup(l.timeouts, "member_data", null)
        tcp_inspect    = lookup(l.timeouts, "tcp_inspect", null)
      }
      pool = {
        protocol    = l.pool.protocol
        method      = l.pool.method
        member_port = l.pool.member_port
        monitor     = l.pool.monitor
        members = {
          for m in l.pool.members : m => {
            address = module.instance[split(".", m)[0]].ports[split(".", m)[1]].ip
            subnet_id = local.subnet_ids[join("/", [
              local.instance_ports[split(".", m)[0]][split(".", m)[1]].network,
              local.instance_ports[split(".", m)[0]][split(".", m)[1]].subnet,
            ])]
          }
        }
      }
    }
  }
}
