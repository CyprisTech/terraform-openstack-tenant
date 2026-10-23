variable "project_id" {
  description = <<-EOT
    Project that owns the zones and records. Leave null for the project of the provider's
    credentials. With admin credentials, setting it creates the zones *for* that project
    (X-Auth-Sudo-Tenant-ID): the project owns them while this configuration keeps managing them.
    Zones are never transferred after creation.
  EOT
  type        = string
  default     = null
}

variable "zones" {
  description = "Zones to create, keyed by name: { name (with trailing dot), email, ttl, description }."
  type = map(object({
    name        = string
    email       = string
    ttl         = optional(number)
    description = optional(string, "")
  }))
  default = {}

  validation {
    condition     = alltrue([for z in values(var.zones) : endswith(z.name, ".")])
    error_message = "Zone names must end with a dot."
  }
}

variable "records" {
  description = <<-EOT
    Record sets keyed by name.
    - zone: key in zones, for a zone created here; or zone_id and zone_name for a zone owned
      by the project or shared with it (zone_name, with its trailing dot, builds the record name).
    - name: relative name; "" is the zone apex.
    - type: A, AAAA, CNAME, MX, TXT, SRV, NS, PTR, CAA or SSHFP.
    - records: values; for CNAME, MX, NS, SRV and PTR, targets end with a dot.
  EOT
  type = map(object({
    zone      = optional(string)
    zone_id   = optional(string)
    zone_name = optional(string)
    name      = string
    type      = string
    records   = list(string)
    ttl       = optional(number)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.records) : (r.zone != null) != (r.zone_id != null && r.zone_name != null)])
    error_message = "Each record needs either zone (a key of zones) or both zone_id and zone_name."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "NS", "PTR", "CAA", "SSHFP"], r.type)])
    error_message = "records.*.type must be A, AAAA, CNAME, MX, TXT, SRV, NS, PTR, CAA or SSHFP."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.zone_name == null || endswith(coalesce(r.zone_name, "."), ".")])
    error_message = "records.*.zone_name must end with a dot."
  }
}

variable "default_ttl" {
  description = "TTL of zones and records that do not set one."
  type        = number
  default     = 3000
}
