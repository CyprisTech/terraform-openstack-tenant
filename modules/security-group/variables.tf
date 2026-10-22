variable "name" {
  description = "Name of the security group."
  type        = string
}

variable "description" {
  description = "Description of the security group."
  type        = string
  default     = ""
}

variable "project_id" {
  description = "Project that owns the security group. Leave null to use the project of the provider's credentials; set it only with admin credentials."
  type        = string
  default     = null
}

variable "delete_default_rules" {
  description = "Remove the egress rules Neutron adds to every new security group, so that only declared rules apply."
  type        = bool
  default     = false
}

variable "rules" {
  description = <<-EOT
    Rules keyed by name; adding or removing one never recreates the others.
    - direction: "ingress" or "egress".
    - ethertype: "IPv4" or "IPv6".
    - protocol: "tcp", "udp", "icmp"... null means any.
    - port_min / port_max: port range; null means all ports.
    - remote_ip_prefix: source (ingress) or destination (egress) CIDR.
    - remote_group_id: security group whose members are the source or destination,
      instead of a CIDR. Use "self" for this security group.
    - description: free text.
  EOT
  type = map(object({
    direction        = string
    ethertype        = optional(string, "IPv4")
    protocol         = optional(string)
    port_min         = optional(number)
    port_max         = optional(number)
    remote_ip_prefix = optional(string)
    remote_group_id  = optional(string)
    description      = optional(string, "")
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["ingress", "egress"], r.direction) && contains(["IPv4", "IPv6"], r.ethertype)])
    error_message = "Each rule needs direction ingress or egress, and ethertype IPv4 or IPv6."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : !(r.remote_ip_prefix != null && r.remote_group_id != null)])
    error_message = "A rule takes remote_ip_prefix or remote_group_id, not both."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : (r.port_min == null) == (r.port_max == null)])
    error_message = "Set both port_min and port_max, or neither."
  }
}
