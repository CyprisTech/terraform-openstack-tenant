# Building block: loadbalancer

One Octavia load balancer with its listeners, pools, members and health monitors, plus an optional floating IP on the VIP with DNS records. Usable on its own or through the tenant composite. Requires Octavia.

- Listeners and pools are keyed by listener name; members by `<listener>/<member>`, from input keys only, so member addresses may be unknown at plan time.
- The **topology** (single amphora or active/standby pair) is not a load balancer attribute: it is defined by the Octavia **flavor** created by the cloud administrator. Pass it with `flavor_id` (`openstack loadbalancer flavor list`).
- Use `pool.protocol = "PROXY"` behind a `TCP` listener to pass client addresses to TLS-terminating backends.

```hcl
module "edge" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/loadbalancer?ref=v0.1.0"

  name      = "edge"
  vip       = { subnet_id = module.network.subnets["main"].id }
  flavor_id = var.octavia_ha_flavor_id

  floating_ip = {
    pool = "public"
    dns  = [{ name = "www", zone_id = var.zone_id, zone_name = "example.org." }]
  }

  listeners = {
    https = {
      protocol = "TCP"
      port     = 443
      pool = {
        protocol = "PROXY"
        members  = { for k, m in module.proxy : k => { address = m.ports["main"].ip } }
        monitor  = { type = "TCP" }
      }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_openstack"></a> [openstack](#requirement\_openstack) | ~> 3.2 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_openstack"></a> [openstack](#provider\_openstack) | ~> 3.2 |

## Resources

| Name | Type |
| ---- | ---- |
| [openstack_dns_recordset_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/dns_recordset_v2) | resource |
| [openstack_lb_listener_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_listener_v2) | resource |
| [openstack_lb_loadbalancer_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_loadbalancer_v2) | resource |
| [openstack_lb_member_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_member_v2) | resource |
| [openstack_lb_monitor_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_monitor_v2) | resource |
| [openstack_lb_pool_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_pool_v2) | resource |
| [openstack_networking_floatingip_associate_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2) | resource |
| [openstack_networking_floatingip_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_listeners"></a> [listeners](#input\_listeners) | Listeners keyed by name, each with its pool.<br/>- protocol / port: for example "TCP" 443, "HTTP" 80.<br/>- allowed\_cidrs: source restriction; empty allows all.<br/>- timeouts: client\_data, member\_connect, member\_data, tcp\_inspect (milliseconds).<br/>- connection\_limit: -1 for unlimited.<br/>- insert\_headers: for HTTP listeners, for example { "X-Forwarded-For" = "true" }.<br/>- pool.protocol: "TCP", "HTTP", "PROXY" (passes client addresses to TCP backends)...<br/>- pool.method: "ROUND\_ROBIN", "LEAST\_CONNECTIONS", "SOURCE\_IP"...<br/>- pool.members: keyed by name (keys must be known at plan time): { address, subnet\_id, port, weight, backup }.<br/>  port defaults to pool.member\_port, then to the listener port.<br/>- pool.monitor: { type, delay, timeout, max\_retries, max\_retries\_down, url\_path, http\_method, expected\_codes }. | <pre>map(object({<br/>    protocol         = string<br/>    port             = number<br/>    allowed_cidrs    = optional(list(string), [])<br/>    connection_limit = optional(number)<br/>    insert_headers   = optional(map(string), {})<br/>    timeouts = optional(object({<br/>      client_data    = optional(number)<br/>      member_connect = optional(number)<br/>      member_data    = optional(number)<br/>      tcp_inspect    = optional(number)<br/>    }), {})<br/>    pool = object({<br/>      protocol    = string<br/>      method      = optional(string, "ROUND_ROBIN")<br/>      member_port = optional(number)<br/>      members = map(object({<br/>        address   = string<br/>        subnet_id = optional(string)<br/>        port      = optional(number)<br/>        weight    = optional(number)<br/>        backup    = optional(bool, false)<br/>      }))<br/>      monitor = optional(object({<br/>        type             = string<br/>        delay            = optional(number, 5)<br/>        timeout          = optional(number, 3)<br/>        max_retries      = optional(number, 3)<br/>        max_retries_down = optional(number)<br/>        url_path         = optional(string, "/")<br/>        http_method      = optional(string, "GET")<br/>        expected_codes   = optional(string, "200")<br/>      }))<br/>    })<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the load balancer. Listeners, pools and monitors are named after it. | `string` | n/a | yes |
| <a name="input_vip"></a> [vip](#input\_vip) | Virtual IP: subnet\_id where it is allocated, and an optional fixed address. | <pre>object({<br/>    subnet_id = string<br/>    address   = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Octavia availability zone; null uses the cloud default. | `string` | `null` | no |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL of DNS records that do not set one. | `number` | `3000` | no |
| <a name="input_flavor_id"></a> [flavor\_id](#input\_flavor\_id) | Octavia flavor. The topology (single amphora or active/standby pair) and the amphora size are<br/>defined by flavors created by the cloud administrator; null uses the cloud default. | `string` | `null` | no |
| <a name="input_floating_ip"></a> [floating\_ip](#input\_floating\_ip) | Optional floating IP on the VIP: pool (external network name), subnet\_id, and DNS A records<br/>({ name, zone\_id, zone\_name, ttl }; name "" is the zone apex, zone\_name ends with a dot). | <pre>object({<br/>    pool      = string<br/>    subnet_id = optional(string)<br/>    dns = optional(list(object({<br/>      name      = string<br/>      zone_id   = string<br/>      zone_name = string<br/>      ttl       = optional(number)<br/>    })), [])<br/>  })</pre> | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the resources. Leave null to use the project of the provider's credentials; set it only with admin credentials. | `string` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security groups applied to the VIP port; empty keeps the Octavia default. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_floating_ip"></a> [floating\_ip](#output\_floating\_ip) | Floating IP of the VIP, or null. |
| <a name="output_fqdns"></a> [fqdns](#output\_fqdns) | DNS names pointing at the floating IP. |
| <a name="output_id"></a> [id](#output\_id) | ID of the load balancer. |
| <a name="output_listeners"></a> [listeners](#output\_listeners) | Listeners keyed like the input: { id, pool\_id, port }. |
| <a name="output_vip"></a> [vip](#output\_vip) | Virtual IP: { address, port\_id }. |
<!-- END_TF_DOCS -->
