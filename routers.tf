###############################################
# Routers, extra routes, Ports and Association
###############################################

resource "openstack_networking_router_v2" "router" {
  for_each = {
    for item in flatten([
      for network in var.networks: [
        for subnet in network.subnets: [
          for router in subnet.routers: {
            router_name         = router.name
            subnet_name         = subnet.name
            admin_state_up      = router.admin_state_up
            az_hints            = router.availability_zone_hints
            subnet_id           = try(
              data.openstack_networking_subnet_v2.subnet["${router.external_network_name}-${router.subnet_name}"].id,
              openstack_networking_subnet_v2.subnets["${router.external_network_name}-${router.subnet_name}"].id
            )
            external_network_id = try(
              data.openstack_networking_network_v2.network[router.external_network_name].id,
              openstack_networking_network_v2.networks[router.external_network_name].id
            )
          }
        ] if lookup(subnet, "routers") != null
      ]
    ]): "${item.subnet_name}-${item.router_name}" => item
  }

  name                = each.value.router_name
  admin_state_up      = each.value.admin_state_up
  external_network_id = each.value.external_network_id
  external_fixed_ip {
    subnet_id = each.value.subnet_id
  }
  availability_zone_hints = each.value.az_hints
  depends_on = [
    openstack_networking_subnet_v2.subnets
  ]
}

resource "openstack_networking_port_v2" "router-port" {
  for_each = {
    for item in flatten([
      for network in var.networks: [
        for subnet in network.subnets: [
          for router in subnet.routers: {
            router_name  = router.name
            subnet_name  = subnet.name
            network_name = network.name
            network_id   = openstack_networking_network_v2.networks[network.name].id
            subnet_id    = openstack_networking_subnet_v2.subnets["${network.name}-${subnet.name}"].id
            ip_address   = router.ip_address
          }
        ] if lookup (subnet, "routers") != null
      ]
    ]): "${item.subnet_name}-${item.router_name}" => item
  }

  network_id = each.value.network_id
  fixed_ip {
      subnet_id = each.value.subnet_id
      ip_address = each.value.ip_address
  }
  depends_on = [
    openstack_networking_router_v2.router,
    openstack_networking_subnet_v2.subnets
  ]
}

resource "openstack_networking_router_interface_v2" "router-port-association" {
  for_each = {
    for item in flatten([
      for network in var.networks: [
        for subnet in network.subnets: [
          for router in subnet.routers: {
            router_name = router.name
            subnet_name = subnet.name
            router_id   = openstack_networking_router_v2.router["${subnet.name}-${router.name}"].id
            port_id     = openstack_networking_port_v2.router-port["${subnet.name}-${router.name}"].id
          }
        ] if lookup (subnet, "routers") != null
      ]
    ]): "${item.subnet_name}-${item.router_name}" => item
  }

  router_id = each.value.router_id
  port_id   = each.value.port_id
  depends_on = [
    openstack_networking_port_v2.router-port
  ]
}
