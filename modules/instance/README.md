# Building block: instance

One Nova instance with its ports, data volumes, floating IPs and DNS records. Usable on its own or through the tenant composite.

- **Ports** are keyed by name and attached in key order (the first key is the primary interface). Each port has its own security groups, optional allowed address pairs, or port security disabled for appliances.
- **Boot**: from the image (default), from a new root volume, or from an existing volume (kept when the instance is deleted, for example to rebuild an instance on its surviving disk).
- **Data volumes** are created by the module or attached from elsewhere (`existing`), for data that must outlive the instance.
- **Floating IPs and DNS**: a floating IP per port on demand, with A records on the floating or the fixed address. Record keys use the zone name, so zone IDs may come from another module and still be unknown at plan time.

```hcl
module "web" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/instance?ref=v0.1.0"

  name   = "web-1"
  az     = "nova"
  flavor = "m1.small"
  image  = "ubuntu-24.04"

  ports = {
    main = {
      network_id         = module.network.id
      subnet_id          = module.network.subnets["main"].id
      security_group_ids = [module.web_sg.id]
      floating_ip = {
        pool = "public"
        dns  = [{ name = "www", zone_id = var.zone_id, zone_name = "example.org." }]
      }
    }
  }

  volumes   = { data = { size = 20 } }
  user_data = module.cloudinit.rendered
  labels    = ["web"]
}
```

## Lifecycle rules

Terraform does not allow lifecycle rules to depend on variables, so they are fixed:

- Changes to `user_data`, to the image (including a newer image published under the same name) and to the boot device **do not replace** a running instance. To apply them, replace the instance explicitly:
  ```bash
  tofu apply -replace='module.web.openstack_compute_instance_v2.this'
  ```
- The module sets **no `prevent_destroy`**. Keep data that must survive in a volume created and protected outside the module, and attach it with `existing`.

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
| [openstack_blockstorage_volume_v3.data](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/blockstorage_volume_v3) | resource |
| [openstack_compute_instance_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_volume_attach_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_volume_attach_v2) | resource |
| [openstack_dns_recordset_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/dns_recordset_v2) | resource |
| [openstack_networking_floatingip_associate_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2) | resource |
| [openstack_networking_floatingip_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2) | resource |
| [openstack_networking_port_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_port_v2) | resource |
| [openstack_blockstorage_volume_v3.boot](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/blockstorage_volume_v3) | data source |
| [openstack_blockstorage_volume_v3.data](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/blockstorage_volume_v3) | data source |
| [openstack_images_image_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/images_image_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_az"></a> [az](#input\_az) | Availability zone of the instance and, by default, of its volumes. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the instance. Ports, volumes and floating IPs are named after it. | `string` | n/a | yes |
| <a name="input_ports"></a> [ports](#input\_ports) | Network interfaces, keyed by name. Interfaces are attached in key order; the first key is the primary interface.<br/>- network\_id / subnet\_id: where the port lives.<br/>- fixed\_ip: fixed address; null allocates one.<br/>- security\_group\_ids: security groups of the port. An empty list applies the project's default group.<br/>- port\_security\_enabled: set to false for routing or appliance instances (no security groups then).<br/>- allowed\_address\_pairs: additional addresses the port may use (virtual IPs, keepalived...).<br/>- floating\_ip: { pool (external network name), subnet\_id, dns } to give the port a floating IP.<br/>- dns: A records on the fixed address.<br/>DNS entries are { name, zone\_id, zone\_name, ttl }; name "" is the zone apex. zone\_name (with its<br/>trailing dot) builds the record name and its key, so it must be known at plan time. | <pre>map(object({<br/>    network_id            = string<br/>    subnet_id             = string<br/>    fixed_ip              = optional(string)<br/>    security_group_ids    = optional(list(string), [])<br/>    port_security_enabled = optional(bool, true)<br/>    allowed_address_pairs = optional(list(string), [])<br/>    floating_ip = optional(object({<br/>      pool      = string<br/>      subnet_id = optional(string)<br/>      dns = optional(list(object({<br/>        name      = string<br/>        zone_id   = string<br/>        zone_name = string<br/>        ttl       = optional(number)<br/>      })), [])<br/>    }))<br/>    dns = optional(list(object({<br/>      name      = string<br/>      zone_id   = string<br/>      zone_name = string<br/>      ttl       = optional(number)<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_boot"></a> [boot](#input\_boot) | How the root disk is provided:<br/>- { source = "image" }: ephemeral root disk from the image (default).<br/>- { source = "volume", size, volume\_type }: root volume created from the image, deleted with the instance.<br/>- { source = "existing", id or name }: boot from an existing volume, kept when the instance is deleted. | <pre>object({<br/>    source      = optional(string, "image")<br/>    size        = optional(number)<br/>    volume_type = optional(string)<br/>    id          = optional(string)<br/>    name        = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL of DNS records that do not set one. | `number` | `3000` | no |
| <a name="input_flavor"></a> [flavor](#input\_flavor) | Flavor name. Exactly one of flavor or flavor\_id. | `string` | `null` | no |
| <a name="input_flavor_id"></a> [flavor\_id](#input\_flavor\_id) | Flavor ID. Exactly one of flavor or flavor\_id. | `string` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | Image name; the most recent image with this name is used. Exactly one of image or image\_id, unless boot.source is "existing". | `string` | `null` | no |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | Image ID. Exactly one of image or image\_id, unless boot.source is "existing". | `string` | `null` | no |
| <a name="input_key_pair"></a> [key\_pair](#input\_key\_pair) | Name of a Nova key pair to install. Prefer users and keys in user\_data. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Free labels for the layers above (inventories, cluster bootstrap). Exposed in outputs and in metadata as a comma-separated "labels" key. | `list(string)` | `[]` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Additional instance metadata. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the ports, volumes and floating IPs. Leave null to use the project of the provider's credentials; set it only with admin credentials. | `string` | `null` | no |
| <a name="input_server_group_id"></a> [server\_group\_id](#input\_server\_group\_id) | Server group (affinity or anti-affinity policy) to schedule the instance in. | `string` | `null` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Cloud-init data. Changes are ignored on an existing instance: replace it explicitly (-replace) to apply new data. | `string` | `null` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | Data volumes attached to the instance, keyed by name.<br/>- { size, az, volume\_type }: volume created by the module (az defaults to the instance's).<br/>- { existing = { id or name } }: attach a volume created elsewhere, for data that must<br/>  survive the instance (protect it with its own lifecycle in the configuration that owns it). | <pre>map(object({<br/>    size        = optional(number)<br/>    az          = optional(string)<br/>    volume_type = optional(string)<br/>    existing = optional(object({<br/>      id   = optional(string)<br/>      name = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_az"></a> [az](#output\_az) | Availability zone of the instance. |
| <a name="output_id"></a> [id](#output\_id) | ID of the instance. |
| <a name="output_labels"></a> [labels](#output\_labels) | Labels of the instance, as given. |
| <a name="output_name"></a> [name](#output\_name) | Name of the instance. |
| <a name="output_ports"></a> [ports](#output\_ports) | Ports keyed like the input: { id, ip, floating\_ip, fqdn }. fqdn is the first DNS name of the port (floating first), or null. |
| <a name="output_volumes"></a> [volumes](#output\_volumes) | Attached data volumes keyed like the input: { id }. |
<!-- END_TF_DOCS -->
