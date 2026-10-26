variable "external_network" {
  description = "Name of the external network used as router gateway and floating IP pool."
  type        = string
}

variable "az" {
  description = "Availability zone of the instances."
  type        = string
}

variable "image" {
  description = "Image name (Ubuntu cloud image with cloud-init)."
  type        = string
}

variable "flavor" {
  description = "Flavor of the instances."
  type        = string
}

variable "ssh_public_key" {
  description = "Public key of the ops user, installed on every instance."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the bastion over SSH."
  type        = string
}

variable "zone_name" {
  description = "DNS zone owned by the project, with trailing dot; null on clouds without Designate."
  type        = string
  default     = null
}

variable "dns_nameservers" {
  description = "DNS resolvers given to the instances by DHCP."
  type        = list(string)
  default     = ["9.9.9.9", "1.1.1.1"]
}
