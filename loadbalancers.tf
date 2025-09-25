#############################################
# HA Proxies
#############################################
resource "openstack_lb_loadbalancer_v2" "haproxy" {
  for_each          = { for ha in var.haproxy : ha.name => ha }
  name              = each.value.name
  availability_zone = each.value.az
  vip_subnet_id     = openstack_networking_subnet_v2.subnets["${each.value.vip_net_name}-${each.value.vip_subnet_name}"].id
}

resource "openstack_lb_listener_v2" "haproxy_listener" {
  for_each = {
    for item in flatten([
      for ha in var.haproxy : [
        for listener in ha.listeners : {
          ha_name         = ha.name
          name            = listener.name
          protocol        = listener.protocol
          protocol_port   = listener.port
          loadbalancer_id = openstack_lb_loadbalancer_v2.haproxy[ha.name].id
        }
      ]
    ]) : "${item.ha_name}-${item.name}" => item
  }
  name            = each.value.name
  protocol        = each.value.protocol
  protocol_port   = each.value.protocol_port
  loadbalancer_id = each.value.loadbalancer_id
  depends_on      = [openstack_lb_loadbalancer_v2.haproxy]

  #insert_headers = {
  #  X-Forwarded-For = "true"
  #}
}

resource "openstack_lb_pool_v2" "haproxy_pool" {
  for_each = {
    for item in flatten([
      for ha in var.haproxy : [
        for listener in ha.listeners : {
          ha_name     = ha.name
          name        = listener.name
          protocol    = listener.pool.protocol
          lb_method   = listener.pool.lb_method
          listener_id = openstack_lb_listener_v2.haproxy_listener["${ha.name}-${listener.name}"].id
        }
      ]
    ]) : "${item.ha_name}-${item.name}" => item
  }
  protocol    = each.value.protocol
  lb_method   = each.value.lb_method
  listener_id = each.value.listener_id
  depends_on  = [openstack_lb_listener_v2.haproxy_listener]

  #persistence {
  #  type        = "APP_COOKIE"
  #  cookie_name = "testCookie"
  #}
}

resource "openstack_lb_member_v2" "haproxy_pool_member" {
  for_each = {
    for item in flatten([
      for ha in var.haproxy : [
        for listener in ha.listeners : [
          for instance in var.instances : {
            ha_name       = ha.name
            listener_name = listener.name
            instance_name = instance.name
            protocol_port = listener.port
            host_ip       = local.instance_private_ip_address[instance.name].ip_address
            pool_id       = openstack_lb_pool_v2.haproxy_pool["${ha.name}-${listener.name}"].id
          } if contains(listener.pool.instance_names, instance.name)
        ]
      ]
    ]) : "${item.ha_name}-${item.listener_name}-${item.instance_name}" => item
  }
  pool_id       = each.value.pool_id
  address       = each.value.host_ip
  protocol_port = each.value.protocol_port
  depends_on    = [openstack_lb_pool_v2.haproxy_pool]
}

resource "openstack_lb_monitor_v2" "monitor_http_pool" {
  for_each = {
    for item in flatten([
      for ha in var.haproxy : [
        for listener in ha.listeners : {
          ha_name       = ha.name
          listener_name = listener.name
          pool_id       = openstack_lb_pool_v2.haproxy_pool["${ha.name}-${listener.name}"].id
          type          = listener.pool.monitor.type
          delay         = listener.pool.monitor.delay
          timeout       = listener.pool.monitor.timeout
          max_retries   = listener.pool.monitor.max_retries
        }
      ]
    ]) : "${item.ha_name}-${item.listener_name}" => item
  }
  pool_id     = each.value.pool_id
  type        = each.value.type
  delay       = each.value.delay
  timeout     = each.value.timeout
  max_retries = each.value.max_retries
  depends_on  = [openstack_lb_member_v2.haproxy_pool_member]
}

resource "openstack_networking_floatingip_v2" "ha_floating_ip" {
  for_each = {
    for ha in var.haproxy : ha.name => {
      pool_name = ha.fip_pool_name
      subnet_ids = [try(
        data.openstack_networking_subnet_v2.subnet["${ha.fip_pool_name}-${ha.fip_subnet_name}"].id,
        openstack_networking_subnet_v2.subnets["${ha.fip_pool_name}-${ha.fip_subnet_name}"].id
      )]
    }
  }
  pool       = each.value.pool_name
  subnet_ids = each.value.subnet_ids
}

resource "openstack_networking_floatingip_associate_v2" "ha_fip_association" {
  for_each = {
    for ha in var.haproxy : ha.name => {
      ha_vip_port_id = openstack_lb_loadbalancer_v2.haproxy[ha.name].vip_port_id
      ha_fip_address = openstack_networking_floatingip_v2.ha_floating_ip[ha.name].address
    }
  }
  floating_ip = each.value.ha_fip_address
  port_id     = each.value.ha_vip_port_id
}

resource "openstack_dns_recordset_v2" "ha_fip_recordset" {
  for_each = {
    for item in flatten([
      for zone in var.data.project_zones : [
        for ha in var.haproxy : [
          for listener in ha.listeners : [
            for record in listener.dns_record_names : {
              zone_fqdn   = zone
              ha_name     = ha.name
              record_name = record
              fip_address = openstack_networking_floatingip_v2.ha_floating_ip[ha.name].address
            }
          ] if lookup(listener, "dns_record_names", null) != null
        ]
      ]
    ]) : "${item.ha_name}-${item.record_name}" => item
  }
  zone_id     = data.openstack_dns_zone_v2.zone[each.value.zone_fqdn].id
  name        = "${each.value.record_name}.${each.value.zone_fqdn}"
  description = ""
  ttl         = 3000
  type        = "A"
  records     = [each.value.fip_address]
}
