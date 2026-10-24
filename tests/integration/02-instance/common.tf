# tflint-ignore-file: terraform_unused_declarations
# The same variables are shared by every stage (one env.tfvars); each stage uses a subset.

terraform {
  required_version = ">= 1.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.2"
    }
  }
}

# Credentials come from clouds.yaml (OS_CLOUD); run.sh unsets every other OS_* variable.
provider "openstack" {}

variable "external_network" {
  description = "Name of an external network usable as router gateway and floating IP pool."
  type        = string
}

variable "second_external_network" {
  description = "Name of a second external network, reached through a second router (stage 04)."
  type        = string
  default     = null
}

variable "second_external_cidr" {
  description = "Destination reached through the second router, advertised to the subnet (stage 04)."
  type        = string
  default     = null
}

variable "az" {
  description = "Availability zone for instances and volumes."
  type        = string
}

variable "image" {
  description = "Image name (an Ubuntu cloud image with cloud-init)."
  type        = string
}

variable "flavor" {
  description = "Small flavor with a local disk, for instances booting from the image."
  type        = string
}

variable "flavor_nodisk" {
  description = "Small flavor without local disk, for instances booting from a volume."
  type        = string
}

variable "zone_name" {
  description = "DNS zone owned by the test project (with trailing dot)."
  type        = string
}

variable "shared_zone_name" {
  description = "DNS zone owned by another project and shared with the test project (with trailing dot)."
  type        = string
}

variable "shared_security_group" {
  description = "Name of a security group shared with the test project, adopted by name (stage 04)."
  type        = string
  default     = null
}
