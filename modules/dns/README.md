# Building block: dns

Designate zones and record sets. Usable on its own or through the tenant composite. Requires Designate.

- **Zones** created here belong to the project of the provider's credentials. With admin credentials, `project_id` creates them **for** another project (`X-Auth-Sudo-Tenant-ID`): that project owns them and manages its records, while this configuration still sees them. Zones are never transferred after creation: a transfer hides the zone from the stack that created it.
- **Records** go into a zone created here (`zone`, a key of `zones`) or into a zone owned by the project or shared with it (`zone_id` and `zone_name`). The record name is built from the zone name, so a zone ID coming from another module may be unknown at plan time.

```hcl
module "dns" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/dns?ref=v0.1.0"

  zones = {
    app = { name = "app.example.org.", email = "hostmaster@example.org" }
  }
  records = {
    apex = { zone = "app", name = "", type = "A", records = ["192.0.2.10"] }
    mail = { zone = "app", name = "", type = "MX", records = ["10 mail.example.org."] }
    api  = { zone_id = var.shared_zone_id, zone_name = "svc.example.org.", name = "api", type = "CNAME", records = ["api.app.example.org."] }
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
| [openstack_dns_recordset_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/dns_recordset_v2) | resource |
| [openstack_dns_zone_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/dns_zone_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL of zones and records that do not set one. | `number` | `3000` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the zones and records. Leave null for the project of the provider's<br/>credentials. With admin credentials, setting it creates the zones *for* that project<br/>(X-Auth-Sudo-Tenant-ID): the project owns them while this configuration keeps managing them.<br/>Zones are never transferred after creation. | `string` | `null` | no |
| <a name="input_records"></a> [records](#input\_records) | Record sets keyed by name.<br/>- zone: key in zones, for a zone created here; or zone\_id and zone\_name for a zone owned<br/>  by the project or shared with it (zone\_name, with its trailing dot, builds the record name).<br/>- name: relative name; "" is the zone apex.<br/>- type: A, AAAA, CNAME, MX, TXT, SRV, NS, PTR, CAA or SSHFP.<br/>- records: values; for CNAME, MX, NS, SRV and PTR, targets end with a dot. | <pre>map(object({<br/>    zone      = optional(string)<br/>    zone_id   = optional(string)<br/>    zone_name = optional(string)<br/>    name      = string<br/>    type      = string<br/>    records   = list(string)<br/>    ttl       = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Zones to create, keyed by name: { name (with trailing dot), email, ttl, description }. | <pre>map(object({<br/>    name        = string<br/>    email       = string<br/>    ttl         = optional(number)<br/>    description = optional(string, "")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_records"></a> [records](#output\_records) | Record sets keyed like the input: { id, fqdn }. |
| <a name="output_zones"></a> [zones](#output\_zones) | Zones keyed like the input: { id, name }. |
<!-- END_TF_DOCS -->
