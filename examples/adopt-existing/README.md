# Adopting existing objects

A tenant that relies on objects owned by others:

- the transit network and a monitoring security group are adopted **by ID** (for example outputs of the cloud baseline);
- the management network and baseline security groups are adopted **by name**, and a management port is added to the instance with a plain `merge` (the module has no special option for it);
- a DNS zone owned by the project and a zone **shared** by the administrator;
- an instance that boots from an existing root volume and attaches an existing data volume created and protected outside the module.

Runs with a member role on the project.

## Run

The objects to adopt must exist before the first plan: those given by name are looked up at plan time, those given by ID are used as they are.

```bash
export OS_CLOUD=mycloud
tofu init
tofu apply \
  -var transit_network_id=<id> -var transit_subnet_id=<id> \
  -var monitoring_security_group_id=<id> \
  -var shared_services_zone_id=<id> -var db_data_volume_id=<id>
```

A zone is usable only if the project owns it or if it is shared with the project; transferring a zone hides it from the stack that created it ([tenant model](../../docs/tenant-model.md#existing)). The adopted volume is never deleted by `destroy`: it belongs to the stack that created it.
