variable "tenant" {
  description = <<-EOT
    Declarative model of the tenant: adopted objects, networks, routers,
    security groups, instances, load balancers and DNS. Every collection is
    a map keyed by name; objects reference each other by key.
    See docs/tenant-model.md for the meaning of every attribute.
  EOT
  type = object({
    # Only for labs: create the project (requires admin credentials).
    # Otherwise resources are created in the project of the provider's token.
    project = optional(object({
      create      = optional(bool, false)
      name        = optional(string)
      description = optional(string, "")
      quotas = optional(object({
        compute = optional(object({ cores = optional(number), ram = optional(number), instances = optional(number) }), {})
        network = optional(map(number), {})
        volume  = optional(map(number), {})
      }), {})
    }), {})

    role_assignments = optional(map(object({
      kind = string # "user" or "group"
      name = string
      role = string
    })), {})

    # Objects owned elsewhere, adopted by ID (no lookup) or by name (lookup, must exist).
    existing = optional(object({
      networks = optional(map(object({
        id      = optional(string)
        name    = optional(string)
        subnets = optional(map(object({ id = optional(string), name = optional(string) })), {})
      })), {})
      security_groups = optional(map(object({ id = optional(string), name = optional(string) })), {})
      dns_zones       = optional(map(object({ id = optional(string), name = optional(string) })), {})
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
          pool   = string
          subnet = optional(string)
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
      vip      = object({ network = string, subnet = string, ip = optional(string) })
      topology = optional(string, "SINGLE")
      flavor   = optional(string)
      floating_ip = optional(object({
        pool   = string
        subnet = optional(string)
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
      [for k, z in var.tenant.existing.dns_zones : (z.id == null) != (z.name == null)],
    ))
    error_message = "Each existing object needs exactly one of id or name."
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
}
