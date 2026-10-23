variable "octavia_flavor_id" {
  description = "Octavia flavor with the active/standby topology; null uses the cloud default."
  type        = string
  default     = null
}
