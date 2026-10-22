variable "transit_network_id" {
  description = "ID of the shared transit network, for example an output of the cloud baseline."
  type        = string
}

variable "transit_subnet_id" {
  description = "ID of the transit subnet used for the router gateway."
  type        = string
}

variable "monitoring_security_group_id" {
  description = "ID of a security group shared by the administrator for monitoring access."
  type        = string
}

variable "shared_services_zone_id" {
  description = "ID of a DNS zone owned by the administrator and shared with this project."
  type        = string
}

variable "db_data_volume_id" {
  description = "ID of a data volume created and protected outside the module."
  type        = string
}
