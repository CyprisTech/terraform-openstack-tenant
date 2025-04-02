#####################
# Openstack provider
#####################

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

#################################################
# TBD: we are currently relying on env variable
#################################################

provider "openstack" {
#  auth_url    = var.auth_url
#  tenant_name = "admin"
#  user_name   = var.user_name
#  password    = var.password
#  region      = var.region
}

