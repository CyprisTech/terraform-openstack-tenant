variable "ssh_public_key" {
  description = "Public key installed for the ops user."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the instances over SSH."
  type        = string
}
