###########################
# Create or Import Flavors
###########################

resource "openstack_compute_flavor_v2" "flavors" {
  for_each = { for flv in var.flavors : flv.name => flv }

  name  = each.value.name
  ram   = each.value.ram
  vcpus = each.value.vcpus
  disk  = each.value.disk
  is_public = true
}

data "openstack_compute_flavor_v2" "flavors" {
  for_each = { for flv in var.data.flavors : flv => {} }
  name  = each.key
}
