terraform {
  required_version = ">= 1.9"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.2"
    }
  }
}

# Credentials come from clouds.yaml; select the entry with OS_CLOUD.
provider "openstack" {}
