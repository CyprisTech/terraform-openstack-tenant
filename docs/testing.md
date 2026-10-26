# Testing

The modules are tested at two levels:

| Level | What | Where | When |
|---|---|---|---|
| Mocked | Key stability, validation rules, output shape, single plan on a complete tenant | `tests/*.tftest.hcl` | CI, on every pull request, with OpenTofu and Terraform |
| Integration | Real resources on a real OpenStack cloud: apply, **empty plan after apply**, destroy | [`tests/integration/`](../tests/integration/README.md) | Before every release, on each reference cloud |

Mocked tests cannot see how a real cloud and the provider behave (attributes read back differently, service-side defaults). The integration tests exist for that: every defect listed below was invisible to the mocked tests.

## Integration results

### Pre-release (`main` before `v0.1.0`), October 2026

**Cloud:** private cloud, OpenStack 2025.1 deployed with OpenStack-Ansible (Nova, Neutron with OVN, Cinder LVM, Glance, Octavia amphora, Designate). Project-scoped application credential with the `member` and `load-balancer_member` roles.
**Tools:** OpenTofu 1.13.2, provider `terraform-provider-openstack/openstack` 3.4.0.

| Stage | Apply | Empty plan after apply | Destroy | Apply duration | Notes |
|---|---|---|---|---|---|
| `01-network` | ✅ | ✅ | ✅ | 21 s (full run) | The only router of the subnet holds the subnet's gateway address |
| `02-instance` | ✅ | ✅ | ✅ | 119 s | Boot from a module-created root volume; data disk formatted and mounted by the `disk-data` unit; A records on the fixed and floating addresses |
| `03-loadbalancer` | ✅ | ✅ | ✅ | 551 s (amphora build ~2 min) | Load balancer and both members `ONLINE`, TCP monitor `ONLINE`; record written in a zone shared with the project; rule between local security groups. **Re-run 2026-10-26** after the `v0.1` changes (soft anti-affinity server group on the web members): 25 resources, full cycle 654 s, all ✅ |
| `04-complete` | ✅ | ✅ | ✅ | 46 s | Two routers on one subnet: the first holds the gateway address, the second gets an allocated address and its advertised route reaches the instance through DHCP; adopted shared security group on a port; second port on another network; rule between local groups; CNAME record. **Re-run 2026-10-26** after `management_port` was replaced by a plain port: 21 resources, full cycle 66 s, all ✅ |

#### Example `three-tier-ha` (2026-10-26)

Applied from `examples/three-tier-ha` on the same cloud: 51 resources in 130 s, **empty plan after apply**, 51 destroyed in 90 s.

- Hard anti-affinity: `data-1` and `data-2` on two different hosts. Soft anti-affinity: `web-1` and `web-2` on two hosts, but `app-1` and `app-2` on the same host while another host had room. Soft anti-affinity is a scheduler weight, not a guarantee, and instances created in parallel can land together. Use `anti-affinity` when separation matters.
- Load balancer `ACTIVE`, members in `ERROR` as expected: the example installs no application, so nothing listens on port 8443.
- A records for `www` (load balancer) and `bastion` written in the project zone.
- Second run, kept up for checks: SSH through the bastion works once `admin_cidrs` covers the address the cloud's routers use on the external network (here a router address in the external subnet, not the operator's own address). Verified through the bastion:
  - both data instances mount `/dev/vdb` (ext4, label `data`) on `/var/lib/postgresql` through the `disk-data` unit;
  - isolation between tiers, by connection result (refused = allowed by the security groups, nothing listening; timeout = dropped): app → data 5432 refused, data → data 5432 refused, web → app 8080 refused, web → data 5432 timeout, data → app 8080 timeout, web → data 22 timeout.
- The load balancer went to `ERROR` once during creation (cloud-side, Octavia); the same configuration rebuilt with `-replace` reached `ACTIVE`. A load balancer in `ERROR` can block refresh: Octavia removes its VIP port, and the provider then fails to read it (`PortNotFound`). Recovery: `tofu apply -refresh-only -target=<other resources>`, then `tofu apply -refresh=false -replace=<load balancer address>`. See the [operations guide](operations.md).

### Public cloud (OVHcloud Public Cloud, region BHS5), October 2026

**Status:** blocked by the project quotas, not by the module. A new project has Neutron quotas `security_group = 0` and `security_group_rule = 0` (only the `default` group exists), so the first security group fails with `409 OverQuota`. The Control panel only offers compute quota tiers through a prepaid credit; a support request for the two network quotas is in progress.

Read-only checks and plans already pass on this cloud: authentication with an application credential, external network `Ext-Net`, Octavia (flavors `small` to `xl`), no Designate (DNS records are skipped), single external network (both routers of stage 04 use it). Plans: 7, 14, 23 and 20 resources for stages 01 to 04.

### Defects found by the integration tests

| # | Defect | Symptom | Fix |
|---|---|---|---|
| 1 | Empty `availability_zone_hints` sent as `[]` | The provider reads `[]` back as unknown and the attribute forces replacement: **every plan after apply recreated the network**, its subnet, router port and interface | Send `null` when the list is empty (networks and routers) |
| 2 | Root volume created by Nova (`block_device` from image) | Nova did not pass its availability zone to Cinder, which fell back to its default zone: `NoValidBackend`, instance in `ERROR`. The data volume of the same run, created with an explicit zone, succeeded | The module creates the root volume itself, in zone `boot.az` (defaults to the instance zone), and boots from it |

### Environment observations

- Test subnets need DNS resolvers (`dns_nameservers`); without them cloud-init waits for package index timeouts for several minutes (first boot: 420 s without resolvers, 20 s with).
- An image with `shared` visibility and no members is invisible to a project with the `member` role; administrators do not notice it because the `admin` role sees every image.
- On OVHcloud Public Cloud, new projects cannot create security groups until the network quotas are raised by support.
