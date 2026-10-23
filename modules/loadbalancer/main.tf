locals {
  # Member keys combine listener and member keys, both from the input, so they
  # are known at plan time even when member addresses are not.
  members = merge([
    for lk, l in var.listeners : {
      for mk, m in l.pool.members : "${lk}/${mk}" => merge(m, {
        listener = lk
        port     = coalesce(m.port, l.pool.member_port, l.port)
      })
    }
  ]...)

  dns_records = var.floating_ip == null ? {} : {
    for d in var.floating_ip.dns : "${d.name}@${d.zone_name}" => d
  }
}

resource "openstack_lb_loadbalancer_v2" "this" {
  name               = var.name
  tenant_id          = var.project_id
  vip_subnet_id      = var.vip.subnet_id
  vip_address        = var.vip.address
  flavor_id          = var.flavor_id
  availability_zone  = var.availability_zone
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
}

resource "openstack_lb_listener_v2" "this" {
  for_each = var.listeners

  name                   = "${var.name}-${each.key}"
  tenant_id              = var.project_id
  loadbalancer_id        = openstack_lb_loadbalancer_v2.this.id
  protocol               = each.value.protocol
  protocol_port          = each.value.port
  allowed_cidrs          = length(each.value.allowed_cidrs) > 0 ? each.value.allowed_cidrs : null
  connection_limit       = each.value.connection_limit
  insert_headers         = length(each.value.insert_headers) > 0 ? each.value.insert_headers : null
  timeout_client_data    = each.value.timeouts.client_data
  timeout_member_connect = each.value.timeouts.member_connect
  timeout_member_data    = each.value.timeouts.member_data
  timeout_tcp_inspect    = each.value.timeouts.tcp_inspect
}

resource "openstack_lb_pool_v2" "this" {
  for_each = var.listeners

  name        = "${var.name}-${each.key}"
  tenant_id   = var.project_id
  listener_id = openstack_lb_listener_v2.this[each.key].id
  protocol    = each.value.pool.protocol
  lb_method   = each.value.pool.method
}

resource "openstack_lb_member_v2" "this" {
  for_each = local.members

  name          = each.key
  tenant_id     = var.project_id
  pool_id       = openstack_lb_pool_v2.this[each.value.listener].id
  address       = each.value.address
  subnet_id     = each.value.subnet_id
  protocol_port = each.value.port
  weight        = each.value.weight
  backup        = each.value.backup
}

resource "openstack_lb_monitor_v2" "this" {
  for_each = { for k, l in var.listeners : k => l.pool.monitor if l.pool.monitor != null }

  name             = "${var.name}-${each.key}"
  tenant_id        = var.project_id
  pool_id          = openstack_lb_pool_v2.this[each.key].id
  type             = each.value.type
  delay            = each.value.delay
  timeout          = each.value.timeout
  max_retries      = each.value.max_retries
  max_retries_down = each.value.max_retries_down
  url_path         = contains(["HTTP", "HTTPS"], each.value.type) ? each.value.url_path : null
  http_method      = contains(["HTTP", "HTTPS"], each.value.type) ? each.value.http_method : null
  expected_codes   = contains(["HTTP", "HTTPS"], each.value.type) ? each.value.expected_codes : null
}

resource "openstack_networking_floatingip_v2" "this" {
  count = var.floating_ip == null ? 0 : 1

  pool        = var.floating_ip.pool
  subnet_id   = var.floating_ip.subnet_id
  tenant_id   = var.project_id
  description = var.name
}

resource "openstack_networking_floatingip_associate_v2" "this" {
  count = var.floating_ip == null ? 0 : 1

  floating_ip = openstack_networking_floatingip_v2.this[0].address
  port_id     = openstack_lb_loadbalancer_v2.this.vip_port_id
}

resource "openstack_dns_recordset_v2" "this" {
  for_each = local.dns_records

  zone_id = each.value.zone_id
  name    = each.value.name == "" ? each.value.zone_name : "${each.value.name}.${each.value.zone_name}"
  type    = "A"
  ttl     = coalesce(each.value.ttl, var.default_ttl)
  records = [openstack_networking_floatingip_v2.this[0].address]
}
