# Building block: security-group

One Neutron security group and its rules, keyed by name: adding or removing a rule never recreates the others. Usable on its own or through the tenant composite.

```hcl
module "web_sg" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/security-group?ref=v0.1.0"

  name = "web"
  rules = {
    https     = { direction = "ingress", protocol = "tcp", port_min = 443, port_max = 443, remote_ip_prefix = "0.0.0.0/0" }
    from-self = { direction = "ingress", remote_group_id = "self" } # traffic between members
  }
}
```

Set `delete_default_rules = true` to drop the egress rules Neutron adds to every new group, so that only declared rules apply.

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
| [openstack_networking_secgroup_rule_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name of the security group. | `string` | n/a | yes |
| <a name="input_delete_default_rules"></a> [delete\_default\_rules](#input\_delete\_default\_rules) | Remove the egress rules Neutron adds to every new security group, so that only declared rules apply. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the security group. | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the security group. Leave null to use the project of the provider's credentials; set it only with admin credentials. | `string` | `null` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | Rules keyed by name; adding or removing one never recreates the others.<br/>- direction: "ingress" or "egress".<br/>- ethertype: "IPv4" or "IPv6".<br/>- protocol: "tcp", "udp", "icmp"... null means any.<br/>- port\_min / port\_max: port range; null means all ports.<br/>- remote\_ip\_prefix: source (ingress) or destination (egress) CIDR.<br/>- remote\_group\_id: security group whose members are the source or destination,<br/>  instead of a CIDR. Use "self" for this security group.<br/>- description: free text. | <pre>map(object({<br/>    direction        = string<br/>    ethertype        = optional(string, "IPv4")<br/>    protocol         = optional(string)<br/>    port_min         = optional(number)<br/>    port_max         = optional(number)<br/>    remote_ip_prefix = optional(string)<br/>    remote_group_id  = optional(string)<br/>    description      = optional(string, "")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | ID of the security group. |
| <a name="output_name"></a> [name](#output\_name) | Name of the security group. |
| <a name="output_rule_ids"></a> [rule\_ids](#output\_rule\_ids) | IDs of the rules, keyed like the input. |
<!-- END_TF_DOCS -->
