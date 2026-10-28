# Building blocks without the composite

Calls `modules/network`, `modules/security-group` and `modules/instance` directly and wires them with IDs. Use this approach when the composite's single model does not fit your split, or when you only need part of the features.

## Run

```bash
export OS_CLOUD=mycloud
tofu init && tofu apply
```

From a registry, a building block is addressed with a subdirectory: `source = "CyprisTech/tenant/openstack//modules/network"`. Each block documents its interface in its own README (`modules/<block>/README.md`). Output: `web_ip`.
