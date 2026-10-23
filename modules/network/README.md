# Building block: network

One Neutron network with its subnets, and routers that connect a subnet to external networks. Usable on its own or through the tenant composite.

- Subnets, routers and host routes are keyed by input keys, so a single `plan` is enough.
- Each router is attached through a dedicated port, so several routers can serve the same subnet (one per network plane), each with a fixed address if needed.
- `advertise_routes` pushes host routes to the subnet with the router's address as next hop.

```hcl
module "network" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/network?ref=v0.1.0"

  name    = "app"
  subnets = { main = { cidr = "192.168.10.0/24", gateway_ip = "192.168.10.1" } }
  routers = {
    out = {
      external_network_id = data.openstack_networking_network_v2.public.id
      internal_subnet     = "main"
      internal_ip         = "192.168.10.1" # default gateway of the subnet
    }
    to-transit = {
      external_network_id = var.transit_network_id
      internal_subnet     = "main"
      advertise_routes    = ["10.10.0.0/22"]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_openstack"></a> [openstack](#requirement\_openstack) | ~> 3.2 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_openstack"></a> [openstack](#provider\_openstack) | ~> 3.2 |

## Resources

| Name | Type |
| ---- | ---- |
| [openstack_networking_network_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2) | resource |
| [openstack_networking_port_v2.router](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_port_v2) | resource |
| [openstack_networking_router_interface_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_interface_v2) | resource |
| [openstack_networking_router_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_v2) | resource |
| [openstack_networking_subnet_route_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_route_v2) | resource |
| [openstack_networking_subnet_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name of the network. Subnets and routers are named after it: <name>-<subnet key>, <name>-<router key>. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnets of the network, keyed by name.<br/>- cidr: range of the subnet.<br/>- ip\_version: 4 or 6.<br/>- gateway\_ip: default gateway; null takes the first address of the range.<br/>- enable\_dhcp: whether DHCP serves the subnet.<br/>- dns\_nameservers: resolvers pushed by DHCP, in order.<br/>- allocation\_pools: ranges DHCP may allocate; empty means the whole range.<br/>- host\_routes: static routes pushed by DHCP ({ destination, nexthop }). | <pre>map(object({<br/>    cidr             = string<br/>    ip_version       = optional(number, 4)<br/>    gateway_ip       = optional(string)<br/>    enable_dhcp      = optional(bool, true)<br/>    dns_nameservers  = optional(list(string), [])<br/>    allocation_pools = optional(list(object({ start = string, end = string })), [])<br/>    host_routes      = optional(list(object({ destination = string, nexthop = string })), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_admin_state_up"></a> [admin\_state\_up](#input\_admin\_state\_up) | Administrative state of the network. | `bool` | `true` | no |
| <a name="input_availability_zone_hints"></a> [availability\_zone\_hints](#input\_availability\_zone\_hints) | Availability zones where the network may be scheduled. | `list(string)` | `[]` | no |
| <a name="input_mtu"></a> [mtu](#input\_mtu) | MTU of the network. Null keeps the cloud default. | `number` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the resources. Leave null to use the project of the provider's credentials; set it only with admin credentials. | `string` | `null` | no |
| <a name="input_routers"></a> [routers](#input\_routers) | Routers connecting one subnet of this network to an external network, keyed by name.<br/>- external\_network\_id: network providing the gateway.<br/>- external\_subnet\_id: subnet of that network for the gateway address; null lets Neutron choose.<br/>- external\_ip: fixed gateway address; requires external\_subnet\_id.<br/>- internal\_subnet: key of the subnet of this network the router is attached to.<br/>- internal\_ip: fixed router address on that subnet.<br/>- default\_gateway: give this router the subnet's gateway address (the default route of the<br/>  instances). When no router of a subnet sets internal\_ip or default\_gateway, the first<br/>  router of that subnet in key order is the default gateway; other routers get an<br/>  allocated address and are reached through advertise\_routes.<br/>- advertise\_routes: destinations pushed to the internal subnet as host routes via this router. | <pre>map(object({<br/>    external_network_id     = string<br/>    external_subnet_id      = optional(string)<br/>    external_ip             = optional(string)<br/>    internal_subnet         = string<br/>    internal_ip             = optional(string)<br/>    default_gateway         = optional(bool)<br/>    advertise_routes        = optional(list(string), [])<br/>    admin_state_up          = optional(bool, true)<br/>    availability_zone_hints = optional(list(string), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | ID of the network. |
| <a name="output_name"></a> [name](#output\_name) | Name of the network. |
| <a name="output_routers"></a> [routers](#output\_routers) | Routers keyed like the input: { id, internal\_ip }. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Subnets keyed like the input: { id, cidr, gateway\_ip }. |
<!-- END_TF_DOCS -->
