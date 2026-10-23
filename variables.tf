variable "tenant" {
  description = <<-EOT
    Declarative model of the tenant: adopted objects, networks, routers,
    security groups, instances, load balancers and DNS. Every collection is
    a map keyed by name; objects reference each other by key.
    See docs/tenant-model.md for the meaning of every attribute.
  EOT
  type = object({
    # Objects owned elsewhere, adopted by ID (may be created in the same apply)
    # or by name (looked up at plan time, must exist). DNS zones always need
    # their name, which builds record names; their ID is optional.
    existing = optional(object({
      networks = optional(map(object({
        id      = optional(string)
        name    = optional(string)
        subnets = optional(map(object({ id = optional(string), name = optional(string) })), {})
      })), {})
      security_groups = optional(map(object({ id = optional(string), name = optional(string) })), {})
      dns_zones       = optional(map(object({ id = optional(string), name = string })), {})
    }), {})

    networks = optional(map(object({
      name                    = optional(string) # defaults to the map key
      mtu                     = optional(number)
      admin_state_up          = optional(bool, true)
      availability_zone_hints = optional(list(string), [])
      subnets = map(object({
        cidr             = string
        ip_version       = optional(number, 4)
        gateway_ip       = optional(string)
        enable_dhcp      = optional(bool, true)
        dns_nameservers  = optional(list(string), [])
        allocation_pools = optional(list(object({ start = string, end = string })), [])
        host_routes      = optional(list(object({ destination = string, nexthop = string })), [])
      }))
      routers = optional(map(object({
        external_network        = string # key in existing.networks
        external_subnet         = optional(string)
        external_ip             = optional(string)
        internal_subnet         = string # key in this network's subnets
        internal_ip             = optional(string)
        default_gateway         = optional(bool)
        advertise_routes        = optional(list(string), [])
        admin_state_up          = optional(bool, true)
        availability_zone_hints = optional(list(string), [])
      })), {})
    })), {})

    security_groups = optional(map(object({
      description = optional(string, "")
      rules = optional(map(object({
        direction        = string # "ingress" or "egress"
        ethertype        = optional(string, "IPv4")
        protocol         = optional(string)
        port_min         = optional(number)
        port_max         = optional(number)
        remote_ip_prefix = optional(string)
        remote_group     = optional(string) # key of a local or existing security group
      })), {})
    })), {})

    management_port = optional(object({
      network                = string # key in networks or existing.networks
      subnet                 = optional(string)
      security_groups        = list(string)
      egress_security_groups = optional(list(string), [])
    }))

    instances = optional(map(object({
      az        = string
      flavor    = optional(string)
      flavor_id = optional(string)
      image     = optional(string)
      image_id  = optional(string)
      boot = optional(object({
        source      = optional(string, "image") # "image", "volume" or "existing"
        size        = optional(number)
        volume_type = optional(string)
        id          = optional(string)
        name        = optional(string)
      }), {})
      management_port   = optional(bool, false)
      management_egress = optional(bool, false)
      ports = map(object({
        network         = string
        subnet          = string
        fixed_ip        = optional(string)
        security_groups = optional(list(string), [])
        floating_ip = optional(object({
          pool   = string           # key in existing.networks
          subnet = optional(string) # key in that network's subnets
          dns    = optional(list(object({ name = string, zone = string })), [])
        }))
        dns = optional(list(object({ name = string, zone = string })), [])
      }))
      volumes = optional(map(object({
        size        = optional(number)
        az          = optional(string)
        volume_type = optional(string)
        existing    = optional(object({ id = optional(string), name = optional(string) }))
      })), {})
      user_data = optional(string)
      labels    = optional(list(string), [])
      metadata  = optional(map(string), {})
    })), {})

    load_balancers = optional(map(object({
      vip               = object({ network = string, subnet = string, ip = optional(string) })
      flavor_id         = optional(string) # Octavia flavor: defines the topology (single or active/standby)
      availability_zone = optional(string)
      security_groups   = optional(list(string), [])
      floating_ip = optional(object({
        pool   = string           # key in existing.networks
        subnet = optional(string) # key in that network's subnets
        dns    = optional(list(object({ name = string, zone = string })), [])
      }))
      listeners = map(object({
        protocol      = string
        port          = number
        allowed_cidrs = optional(list(string), [])
        timeouts      = optional(map(number), {})
        pool = object({
          protocol    = string
          method      = optional(string, "ROUND_ROBIN")
          members     = list(string) # "<instance>.<port>"
          member_port = optional(number)
          monitor = optional(object({
            type           = string
            delay          = optional(number, 5)
            timeout        = optional(number, 3)
            max_retries    = optional(number, 3)
            url_path       = optional(string)
            expected_codes = optional(string)
          }))
        })
      }))
    })), {})

    dns = optional(object({
      zones = optional(map(object({
        name        = string
        email       = string
        ttl         = optional(number)
        description = optional(string, "")
      })), {})
      records = optional(map(object({
        zone    = string # key in dns.zones or existing.dns_zones
        name    = string
        type    = string
        records = list(string)
        ttl     = optional(number)
      })), {})
    }), {})

    defaults = optional(object({ ttl = optional(number, 3000) }), {})
  })

  validation {
    condition = alltrue(flatten([
      for nk, n in var.tenant.networks : [
        for rk, r in n.routers : contains(keys(var.tenant.existing.networks), r.external_network)
      ]
    ]))
    error_message = "Each router external_network must be a key of tenant.existing.networks."
  }

  validation {
    condition = alltrue(concat(
      [for k, n in var.tenant.existing.networks : (n.id == null) != (n.name == null)],
      [for k, g in var.tenant.existing.security_groups : (g.id == null) != (g.name == null)],
    ))
    error_message = "Each existing network and security group needs exactly one of id or name."
  }

  validation {
    condition = alltrue([
      for k, i in var.tenant.instances :
      contains(["image", "volume", "existing"], i.boot.source) &&
      ((i.flavor == null) != (i.flavor_id == null))
    ])
    error_message = "Each instance needs exactly one of flavor or flavor_id, and boot.source must be image, volume or existing."
  }

  validation {
    condition = alltrue(flatten([
      for ik, i in var.tenant.instances : [
        for pk, p in i.ports :
        contains(concat(keys(var.tenant.networks), keys(var.tenant.existing.networks)), p.network)
      ]
    ]))
    error_message = "Each port network must be a key of tenant.networks or tenant.existing.networks."
  }

  validation {
    condition = alltrue(concat(
      [for k in keys(var.tenant.networks) : !contains(keys(var.tenant.existing.networks), k)],
      [for k in keys(var.tenant.security_groups) : !contains(keys(var.tenant.existing.security_groups), k)],
      [for k in keys(var.tenant.dns.zones) : !contains(keys(var.tenant.existing.dns_zones), k)],
    ))
    error_message = "A key cannot be used both for a local object and an existing one (networks, security_groups, dns zones)."
  }

  validation {
    condition = alltrue(concat(
      flatten([for i in values(var.tenant.instances) : [for p in values(i.ports) : contains(keys(var.tenant.existing.networks), p.floating_ip.pool) if p.floating_ip != null]]),
      [for lb in values(var.tenant.load_balancers) : contains(keys(var.tenant.existing.networks), lb.floating_ip.pool) if lb.floating_ip != null],
    ))
    error_message = "Each floating_ip.pool must be a key of tenant.existing.networks."
  }

  validation {
    condition = alltrue(concat(
      flatten([for i in values(var.tenant.instances) : [for p in values(i.ports) : [for g in p.security_groups : contains(concat(keys(var.tenant.security_groups), keys(var.tenant.existing.security_groups)), g)]]]),
      flatten([for lb in values(var.tenant.load_balancers) : [for g in lb.security_groups : contains(concat(keys(var.tenant.security_groups), keys(var.tenant.existing.security_groups)), g)]]),
      [for g in concat(try(var.tenant.management_port.security_groups, []), try(var.tenant.management_port.egress_security_groups, [])) : contains(concat(keys(var.tenant.security_groups), keys(var.tenant.existing.security_groups)), g)],
      flatten([for sg in values(var.tenant.security_groups) : [for r in values(sg.rules) : contains(concat(keys(var.tenant.security_groups), keys(var.tenant.existing.security_groups)), r.remote_group) if r.remote_group != null]]),
    ))
    error_message = "Every security group reference must be a key of tenant.security_groups or tenant.existing.security_groups."
  }

  validation {
    condition = alltrue(concat(
      flatten([for i in values(var.tenant.instances) : [for p in values(i.ports) : [for d in concat(p.dns, try(p.floating_ip.dns, [])) : contains(concat(keys(var.tenant.dns.zones), keys(var.tenant.existing.dns_zones)), d.zone)]]]),
      flatten([for lb in values(var.tenant.load_balancers) : [for d in try(lb.floating_ip.dns, []) : contains(concat(keys(var.tenant.dns.zones), keys(var.tenant.existing.dns_zones)), d.zone)]]),
      [for r in values(var.tenant.dns.records) : contains(concat(keys(var.tenant.dns.zones), keys(var.tenant.existing.dns_zones)), r.zone)],
    ))
    error_message = "Every DNS zone reference must be a key of tenant.dns.zones or tenant.existing.dns_zones."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.tenant.load_balancers) : [
        for l in values(lb.listeners) : [
          for m in l.pool.members :
          length(split(".", m)) == 2 && contains(keys(var.tenant.instances), split(".", m)[0]) &&
          contains(concat(keys(try(var.tenant.instances[split(".", m)[0]].ports, {})), try(var.tenant.instances[split(".", m)[0]].management_port, false) ? ["management"] : []), try(split(".", m)[1], ""))
        ]
      ]
    ]))
    error_message = "Each load balancer member must be \"<instance>.<port>\" with an existing instance and port key."
  }

  validation {
    condition     = var.tenant.management_port != null || alltrue([for i in values(var.tenant.instances) : !i.management_port])
    error_message = "An instance sets management_port = true but tenant.management_port is not defined."
  }

  validation {
    condition     = alltrue([for i in values(var.tenant.instances) : !contains(keys(i.ports), "management") || !i.management_port])
    error_message = "The port key \"management\" is reserved for the management port."
  }

  validation {
    condition     = alltrue([for z in values(var.tenant.existing.dns_zones) : endswith(z.name, ".")]) && alltrue([for z in values(var.tenant.dns.zones) : endswith(z.name, ".")])
    error_message = "DNS zone names must end with a dot."
  }
}
