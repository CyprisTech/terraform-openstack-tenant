#############################################
# Networks, Subnets and Subnets extra routes
#############################################

###################
# Create Networks
###################
resource "openstack_networking_network_v2" "networks" {
  for_each = { for net in var.networks : net.name => net }

  name             = each.value.name
  mtu              = each.value.mtu
  availability_zone_hints = each.value.az_hints
  admin_state_up   = each.value.admin_state_up
  external         = each.value.external

  dynamic "segments" {
    for_each = (lookup(each.value, "physnet", null) != null ? [1] : [])

    content {
      physical_network = lookup(each.value, "physnet", null)
      network_type     = lookup(each.value, "type", null)
    }
  }

  depends_on = [openstack_compute_aggregate_v2.aggregate]
}

##################
# Create Subnets
##################
resource "openstack_networking_subnet_v2" "subnets" {
  for_each = {
    for item in flatten([
      for network in var.networks : [
        for subnet in network.subnets : {
          net_name = network.name
          subnet_name = subnet.name
          network_id = openstack_networking_network_v2.networks[network.name].id
          ip_version = subnet.ip_version
          cidr = subnet.cidr
          gateway_ip       = lookup(subnet, "gateway_ip", null)
          nameservers      = lookup(subnet, "nameservers", null)
          allocation_pools = lookup(subnet, "allocation_pools", [])
        }
      ]
    ]) : "${item.net_name}-${item.subnet_name}" => item
  }

  name            = each.value.subnet_name
  network_id      = each.value.network_id
  ip_version      = each.value.ip_version
  cidr            = each.value.cidr
  gateway_ip      = each.value.gateway_ip
  dns_nameservers = each.value.nameservers

  dynamic "allocation_pool" {
    for_each = each.value.allocation_pools != null ? each.value.allocation_pools : []
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }

  depends_on = [openstack_networking_network_v2.networks]
}


########################################################################################
# Create Extra routes to support multi segmented networks like intranet and svc_public
########################################################################################

resource "openstack_networking_subnet_route_v2" "subnet_routes" {
  for_each = {
    for item in flatten([
      for network in var.networks : [
        for subnet in network.subnets : [ 
          for route in subnet.extra_routes != null ? subnet.extra_routes : [] : {
            net_name = network.name        
            subnet_name = subnet.name        
            route = route
          }
        ]
      ]
    ]) : "${item.subnet_name}-${item.route.to}" => item
  }

  subnet_id = openstack_networking_subnet_v2.subnets["${each.value.net_name}-${each.value.subnet_name}"].id
  destination_cidr = each.value.route.to
  next_hop     = each.value.route.via

  depends_on = [openstack_networking_subnet_v2.subnets]
}
