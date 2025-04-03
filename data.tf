################################################################
# Data states for Volumes, Networks, Flavors, DNS Zones and SG #
################################################################


###############################################
# Import existing DNS Zones as data resources #
###############################################

data "openstack_dns_zone_v2" "zone" {
  for_each = {
    for zone in var.data.project_zones : zone => { }
  }
  name = each.key
}


#################################################
# Import Networks and Subnets as data resources #
#################################################

data "openstack_networking_network_v2" "network" {
  for_each = {
    for network in var.data.networks : network.name => { }
  }
  name = each.key
}

data "openstack_networking_subnet_v2" "subnet" {
  for_each = {
    for item in flatten([
      for network in var.data.networks : [
        for subnet in network.subnets : {
          network_id  = data.openstack_networking_network_v2.network[network.name].id
          network_name = network.name
          subnet_name = subnet
        }
      ]
    ]): "${item.network_name}-${item.subnet_name}" => item
  }
  name            = each.value.subnet_name
  network_id      = each.value.network_id
}

#########################
# Import Security groups
#########################

data "openstack_networking_secgroup_v2" "sec_groups" {
  for_each = { for sg in var.data.security_groups : sg => {} }
  name        = each.key
}
