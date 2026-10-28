# Minimal tenant without load balancer or DNS

One network, one router to the external network, one instance with a floating IP. The smallest useful tenant, for clouds that do not offer Octavia or Designate, with a member role on the project.

## Run

```bash
export OS_CLOUD=mycloud
tofu init && tofu apply
```

Adapt `external`, `m1.small`, `ubuntu-24.04` and `nova` to the names used by your cloud (`openstack network list --external`, `openstack flavor list`, `openstack image list`). Output: `instances`, with the floating IP of the instance.

The subnet has no resolver: add `dns_nameservers` if the image installs packages at first boot ([pitfalls](../../docs/pitfalls.md#resolvers-at-first-boot)).
