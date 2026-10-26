variable "name" {
  description = "Name of the load balancer. Listeners, pools and monitors are named after it."
  type        = string
}

variable "project_id" {
  description = "Project that owns the resources. Leave null to use the project of the provider's credentials; set it only with admin credentials."
  type        = string
  default     = null
}

variable "vip" {
  description = "Virtual IP: subnet_id where it is allocated, and an optional fixed address."
  type = object({
    subnet_id = string
    address   = optional(string)
  })
}

variable "flavor_id" {
  description = <<-EOT
    Octavia flavor. The topology (single amphora or active/standby pair) and the amphora size are
    defined by flavors created by the cloud administrator; null uses the cloud default.
  EOT
  type        = string
  default     = null
}

variable "availability_zone" {
  description = "Octavia availability zone; null uses the cloud default."
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Security groups applied to the VIP port; empty keeps the Octavia default."
  type        = list(string)
  default     = []
}

variable "floating_ip" {
  description = <<-EOT
    Optional floating IP on the VIP: pool (external network name), subnet_id, and DNS A records
    ({ name, zone_id, zone_name, ttl }; name "" is the zone apex, zone_name ends with a dot).
  EOT
  type = object({
    pool      = string
    subnet_id = optional(string)
    dns = optional(list(object({
      name      = string
      zone_id   = string
      zone_name = string
      ttl       = optional(number)
    })), [])
  })
  default = null

  validation {
    condition     = var.floating_ip == null || alltrue([for d in try(var.floating_ip.dns, []) : endswith(d.zone_name, ".")])
    error_message = "DNS zone_name values must end with a dot."
  }
}

variable "listeners" {
  description = <<-EOT
    Listeners keyed by name, each with its pool.
    - protocol / port: for example "TCP" 443, "HTTP" 80.
    - allowed_cidrs: source restriction; empty allows all.
    - timeouts: client_data, member_connect, member_data, tcp_inspect (milliseconds).
    - connection_limit: -1 for unlimited.
    - insert_headers: for HTTP listeners, for example { "X-Forwarded-For" = "true" }.
    - pool.protocol: "TCP", "HTTP", "PROXY" (passes client addresses to TCP backends)...
    - pool.method: "ROUND_ROBIN", "LEAST_CONNECTIONS", "SOURCE_IP"...
    - pool.members: keyed by name (keys must be known at plan time): { address, subnet_id, port, weight, backup }.
      port defaults to pool.member_port, then to the listener port.
    - pool.monitor: { type, delay, timeout, max_retries, max_retries_down, url_path, http_method, expected_codes }.
  EOT
  type = map(object({
    protocol         = string
    port             = number
    allowed_cidrs    = optional(list(string), [])
    connection_limit = optional(number)
    insert_headers   = optional(map(string), {})
    timeouts = optional(object({
      client_data    = optional(number)
      member_connect = optional(number)
      member_data    = optional(number)
      tcp_inspect    = optional(number)
    }), {})
    pool = object({
      protocol    = string
      method      = optional(string, "ROUND_ROBIN")
      member_port = optional(number)
      members = map(object({
        address   = string
        subnet_id = optional(string)
        port      = optional(number)
        weight    = optional(number)
        backup    = optional(bool, false)
      }))
      monitor = optional(object({
        type             = string
        delay            = optional(number, 5)
        timeout          = optional(number, 3)
        max_retries      = optional(number, 3)
        max_retries_down = optional(number)
        url_path         = optional(string, "/")
        http_method      = optional(string, "GET")
        expected_codes   = optional(string, "200")
      }))
    })
  }))

  validation {
    condition     = length(var.listeners) > 0
    error_message = "A load balancer needs at least one listener."
  }

  validation {
    condition     = alltrue([for l in values(var.listeners) : contains(["TCP", "UDP", "SCTP", "HTTP", "HTTPS", "TERMINATED_HTTPS"], l.protocol)])
    error_message = "listeners.*.protocol must be TCP, UDP, SCTP, HTTP, HTTPS or TERMINATED_HTTPS."
  }

  validation {
    condition     = alltrue([for l in values(var.listeners) : contains(["TCP", "UDP", "SCTP", "HTTP", "HTTPS", "PROXY", "PROXYV2"], l.pool.protocol)])
    error_message = "listeners.*.pool.protocol must be TCP, UDP, SCTP, HTTP, HTTPS, PROXY or PROXYV2."
  }

  # try(): older OpenTofu and Terraform versions evaluate both sides of ||, so
  # "monitor == null || monitor.type ..." fails when there is no monitor.
  validation {
    condition     = alltrue([for l in values(var.listeners) : contains(["PING", "TCP", "HTTP", "HTTPS", "TLS-HELLO", "UDP-CONNECT", "SCTP"], try(l.pool.monitor.type, "TCP"))])
    error_message = "listeners.*.pool.monitor.type must be PING, TCP, HTTP, HTTPS, TLS-HELLO, UDP-CONNECT or SCTP."
  }

  validation {
    condition     = alltrue([for l in values(var.listeners) : length(l.insert_headers) == 0 || contains(["HTTP", "TERMINATED_HTTPS"], l.protocol)])
    error_message = "insert_headers is only supported on HTTP and TERMINATED_HTTPS listeners."
  }
}

variable "default_ttl" {
  description = "TTL of DNS records that do not set one."
  type        = number
  default     = 3000
}
