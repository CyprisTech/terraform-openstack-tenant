resource "openstack_networking_network_v2" "this" {
  name           = var.name
  tenant_id      = var.project_id
  mtu            = var.mtu
  admin_state_up = var.admin_state_up
  # An empty list must be sent as null: the provider treats [] as unset, reads
  # the value back as unknown, and this attribute forces replacement, so every
  # plan after apply would recreate the network (found by integration tests).
  availability_zone_hints = length(var.availability_zone_hints) > 0 ? var.availability_zone_hints : null
}

resource "openstack_networking_subnet_v2" "this" {
  for_each = var.subnets

  name            = "${var.name}-${each.key}"
  tenant_id       = var.project_id
  network_id      = openstack_networking_network_v2.this.id
  cidr            = each.value.cidr
  ip_version      = each.value.ip_version
  gateway_ip      = each.value.gateway_ip
  enable_dhcp     = each.value.enable_dhcp
  dns_nameservers = each.value.dns_nameservers

  dynamic "allocation_pool" {
    for_each = each.value.allocation_pools
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}

resource "openstack_networking_router_v2" "this" {
  for_each = var.routers

  name                    = "${var.name}-${each.key}"
  tenant_id               = var.project_id
  admin_state_up          = each.value.admin_state_up
  availability_zone_hints = length(each.value.availability_zone_hints) > 0 ? each.value.availability_zone_hints : null
  external_network_id     = each.value.external_network_id

  dynamic "external_fixed_ip" {
    for_each = each.value.external_subnet_id == null ? [] : [1]
    content {
      subnet_id  = each.value.external_subnet_id
      ip_address = each.value.external_ip
    }
  }
}

# Each router is attached through a dedicated port rather than by subnet:
# attaching by subnet always takes the subnet's gateway address, so a second
# router on the same subnet would conflict.
resource "openstack_networking_port_v2" "router" {
  for_each = var.routers

  name       = "${var.name}-${each.key}"
  tenant_id  = var.project_id
  network_id = openstack_networking_network_v2.this.id

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.this[each.value.internal_subnet].id
    ip_address = (
      each.value.internal_ip != null ? each.value.internal_ip :
      local.gateway_router[each.value.internal_subnet] == each.key ? openstack_networking_subnet_v2.this[each.value.internal_subnet].gateway_ip :
      null
    )
  }
}

resource "openstack_networking_router_interface_v2" "this" {
  for_each = var.routers

  router_id = openstack_networking_router_v2.this[each.key].id
  port_id   = openstack_networking_port_v2.router[each.key].id
}

locals {
  # The router holding each subnet's gateway address: the one that sets
  # default_gateway = true, otherwise the first router of the subnet in key
  # order, unless some router of the subnet manages its address explicitly.
  gateway_router = {
    for sk in keys(var.subnets) : sk => try(
      [for rk in sort(keys(var.routers)) : rk if var.routers[rk].internal_subnet == sk && var.routers[rk].default_gateway == true][0],
      alltrue([for r in values(var.routers) : r.internal_ip == null && r.default_gateway == null if r.internal_subnet == sk])
      ? [for rk in sort(keys(var.routers)) : rk if var.routers[rk].internal_subnet == sk][0]
      : null,
      null,
    )
  }

  # Keys are built from input keys and destinations only, so they are known at
  # plan time even when the router address is allocated during apply.
  host_routes = merge(
    {
      for item in flatten([
        for sk, s in var.subnets : [
          for r in s.host_routes : { key = "${sk}/${r.destination}", subnet = sk, destination = r.destination, nexthop = r.nexthop, router = null }
        ]
      ]) : item.key => item
    },
    {
      for item in flatten([
        for rk, r in var.routers : [
          for d in r.advertise_routes : { key = "${r.internal_subnet}/${d}", subnet = r.internal_subnet, destination = d, nexthop = null, router = rk }
        ]
      ]) : item.key => item
    },
  )
}

resource "openstack_networking_subnet_route_v2" "this" {
  for_each = local.host_routes

  subnet_id        = openstack_networking_subnet_v2.this[each.value.subnet].id
  destination_cidr = each.value.destination
  next_hop         = each.value.router == null ? each.value.nexthop : openstack_networking_port_v2.router[each.value.router].all_fixed_ips[0]

  depends_on = [openstack_networking_router_interface_v2.this]
}
