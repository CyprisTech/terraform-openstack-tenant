variable "name" {
  description = "Name of the instance. Ports, volumes and floating IPs are named after it."
  type        = string
}

variable "project_id" {
  description = "Project that owns the ports, volumes and floating IPs. Leave null to use the project of the provider's credentials; set it only with admin credentials."
  type        = string
  default     = null
}

variable "az" {
  description = "Availability zone of the instance and, by default, of its volumes."
  type        = string
}

variable "flavor" {
  description = "Flavor name. Exactly one of flavor or flavor_id."
  type        = string
  default     = null
}

variable "flavor_id" {
  description = "Flavor ID. Exactly one of flavor or flavor_id."
  type        = string
  default     = null
}

variable "image" {
  description = "Image name; the most recent image with this name is used. Exactly one of image or image_id, unless boot.source is \"existing\"."
  type        = string
  default     = null
}

variable "image_id" {
  description = "Image ID. Exactly one of image or image_id, unless boot.source is \"existing\"."
  type        = string
  default     = null
}

variable "boot" {
  description = <<-EOT
    How the root disk is provided:
    - { source = "image" }: ephemeral root disk from the image (default).
    - { source = "volume", size, volume_type, az }: root volume created from the image by the module,
      in Cinder availability zone az (defaults to the instance's), deleted with the instance.
    - { source = "existing", id or name }: boot from an existing volume, kept when the instance is deleted.
  EOT
  type = object({
    source      = optional(string, "image")
    size        = optional(number)
    volume_type = optional(string)
    az          = optional(string)
    id          = optional(string)
    name        = optional(string)
  })
  default = {}

  validation {
    condition     = contains(["image", "volume", "existing"], var.boot.source)
    error_message = "boot.source must be image, volume or existing."
  }

  validation {
    condition     = var.boot.source != "volume" || var.boot.size != null
    error_message = "boot.size is required when boot.source is volume."
  }

  validation {
    condition     = var.boot.source != "existing" || ((var.boot.id == null) != (var.boot.name == null))
    error_message = "boot.source = existing needs exactly one of boot.id or boot.name."
  }
}

variable "ports" {
  description = <<-EOT
    Network interfaces, keyed by name. Interfaces are attached in key order; the first key is the primary interface.
    - network_id / subnet_id: where the port lives.
    - fixed_ip: fixed address; null allocates one.
    - security_group_ids: security groups of the port. An empty list applies the project's default group.
    - port_security_enabled: set to false for routing or appliance instances (no security groups then).
    - allowed_address_pairs: additional addresses the port may use (virtual IPs, keepalived...).
    - floating_ip: { pool (external network name), subnet_id, dns } to give the port a floating IP.
    - extra_floating_ips: more floating IPs on the same port, keyed by a free label, same shape as
      floating_ip. One floating IP per external network: all pools of a port must differ, and each
      external network must be reached through its own router.
    - dns: A records on the fixed address.
    DNS entries are { name, zone_id, zone_name, ttl }; name "" is the zone apex. zone_name (with its
    trailing dot) builds the record name and its key, so it must be known at plan time.
  EOT
  type = map(object({
    network_id            = string
    subnet_id             = string
    fixed_ip              = optional(string)
    security_group_ids    = optional(list(string), [])
    port_security_enabled = optional(bool, true)
    allowed_address_pairs = optional(list(string), [])
    floating_ip = optional(object({
      pool      = string
      subnet_id = optional(string)
      dns = optional(list(object({
        name      = string
        zone_id   = string
        zone_name = string
        ttl       = optional(number)
      })), [])
    }))
    extra_floating_ips = optional(map(object({
      pool      = string
      subnet_id = optional(string)
      dns = optional(list(object({
        name      = string
        zone_id   = string
        zone_name = string
        ttl       = optional(number)
      })), [])
    })), {})
    dns = optional(list(object({
      name      = string
      zone_id   = string
      zone_name = string
      ttl       = optional(number)
    })), [])
  }))

  validation {
    condition     = length(var.ports) > 0
    error_message = "An instance needs at least one port."
  }

  validation {
    condition     = alltrue([for p in values(var.ports) : p.port_security_enabled || length(p.security_group_ids) == 0])
    error_message = "A port with port_security_enabled = false cannot have security groups."
  }

  validation {
    condition = alltrue(flatten([
      for p in values(var.ports) : [
        for d in concat(p.dns, try(p.floating_ip.dns, []), flatten([for f in values(p.extra_floating_ips) : f.dns])) : endswith(d.zone_name, ".")
      ]
    ]))
    error_message = "DNS zone_name values must end with a dot."
  }

  validation {
    condition = alltrue([
      for p in values(var.ports) : length(distinct(concat(
        p.floating_ip == null ? [] : [p.floating_ip.pool],
        [for f in values(p.extra_floating_ips) : f.pool],
      ))) == length(p.extra_floating_ips) + (p.floating_ip == null ? 0 : 1)
    ])
    error_message = "The pools of floating_ip and extra_floating_ips of a port must all differ: one floating IP per external network."
  }
}

variable "volumes" {
  description = <<-EOT
    Data volumes attached to the instance, keyed by name.
    - { size, az, volume_type }: volume created by the module (az defaults to the instance's).
    - { existing = { id or name } }: attach a volume created elsewhere, for data that must
      survive the instance (protect it with its own lifecycle in the configuration that owns it).
  EOT
  type = map(object({
    size        = optional(number)
    az          = optional(string)
    volume_type = optional(string)
    existing = optional(object({
      id   = optional(string)
      name = optional(string)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for v in values(var.volumes) : (v.size == null) != (v.existing == null)])
    error_message = "Each volume needs exactly one of size (created) or existing (attached)."
  }

  validation {
    condition     = alltrue([for v in values(var.volumes) : v.existing == null || ((try(v.existing.id, null) == null) != (try(v.existing.name, null) == null))])
    error_message = "volumes.*.existing needs exactly one of id or name."
  }
}

variable "user_data" {
  description = "Cloud-init data. Changes are ignored on an existing instance: replace it explicitly (-replace) to apply new data."
  type        = string
  default     = null
}

variable "key_pair" {
  description = "Name of a Nova key pair to install. Prefer users and keys in user_data."
  type        = string
  default     = null
}

variable "server_group_id" {
  description = "Server group (affinity or anti-affinity policy) to schedule the instance in."
  type        = string
  default     = null
}

variable "labels" {
  description = "Free labels for the layers above (inventories, cluster bootstrap). Exposed in outputs and in metadata as a comma-separated \"labels\" key."
  type        = list(string)
  default     = []
}

variable "metadata" {
  description = "Additional instance metadata."
  type        = map(string)
  default     = {}
}

variable "default_ttl" {
  description = "TTL of DNS records that do not set one."
  type        = number
  default     = 3000
}
