variable "name" {
  description = "Name of the network. Subnets and routers are named after it: <name>-<subnet key>, <name>-<router key>."
  type        = string
}

variable "project_id" {
  description = "Project that owns the resources. Leave null to use the project of the provider's credentials; set it only with admin credentials."
  type        = string
  default     = null
}

variable "mtu" {
  description = "MTU of the network. Null keeps the cloud default."
  type        = number
  default     = null
}

variable "admin_state_up" {
  description = "Administrative state of the network."
  type        = bool
  default     = true
}

variable "availability_zone_hints" {
  description = "Availability zones where the network may be scheduled."
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = <<-EOT
    Subnets of the network, keyed by name.
    - cidr: range of the subnet.
    - ip_version: 4 or 6.
    - gateway_ip: default gateway; null takes the first address of the range.
    - enable_dhcp: whether DHCP serves the subnet.
    - dns_nameservers: resolvers pushed by DHCP, in order.
    - allocation_pools: ranges DHCP may allocate; empty means the whole range.
    - host_routes: static routes pushed by DHCP ({ destination, nexthop }).
  EOT
  type = map(object({
    cidr             = string
    ip_version       = optional(number, 4)
    gateway_ip       = optional(string)
    enable_dhcp      = optional(bool, true)
    dns_nameservers  = optional(list(string), [])
    allocation_pools = optional(list(object({ start = string, end = string })), [])
    host_routes      = optional(list(object({ destination = string, nexthop = string })), [])
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "A network needs at least one subnet."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrhost(s.cidr, 0)) && contains([4, 6], s.ip_version)])
    error_message = "Each subnet needs a valid cidr and an ip_version of 4 or 6."
  }
}

variable "routers" {
  description = <<-EOT
    Routers connecting one subnet of this network to an external network, keyed by name.
    - external_network_id: network providing the gateway.
    - external_subnet_id: subnet of that network for the gateway address; null lets Neutron choose.
    - external_ip: fixed gateway address; requires external_subnet_id.
    - internal_subnet: key of the subnet of this network the router is attached to.
    - internal_ip: fixed router address on that subnet.
    - default_gateway: give this router the subnet's gateway address (the default route of the
      instances). When no router of a subnet sets internal_ip or default_gateway, the first
      router of that subnet in key order is the default gateway; other routers get an
      allocated address and are reached through advertise_routes.
    - advertise_routes: destinations pushed to the internal subnet as host routes via this router.
  EOT
  type = map(object({
    external_network_id     = string
    external_subnet_id      = optional(string)
    external_ip             = optional(string)
    internal_subnet         = string
    internal_ip             = optional(string)
    default_gateway         = optional(bool)
    advertise_routes        = optional(list(string), [])
    admin_state_up          = optional(bool, true)
    availability_zone_hints = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for k, r in var.routers : contains(keys(var.subnets), r.internal_subnet)])
    error_message = "Each router internal_subnet must be a key of subnets."
  }

  validation {
    condition = alltrue([
      for sk in distinct([for r in values(var.routers) : r.internal_subnet]) :
      length([for r in values(var.routers) : r if r.internal_subnet == sk && r.default_gateway == true]) <= 1
    ])
    error_message = "At most one router per subnet can set default_gateway = true."
  }

  validation {
    condition     = alltrue([for r in values(var.routers) : !(r.default_gateway == true && r.internal_ip != null)])
    error_message = "A router takes either default_gateway = true or an explicit internal_ip, not both."
  }

  validation {
    condition     = alltrue([for r in values(var.routers) : r.external_ip == null || r.external_subnet_id != null])
    error_message = "A router external_ip requires external_subnet_id."
  }
}
