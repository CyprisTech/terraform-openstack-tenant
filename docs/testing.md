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
| `03-loadbalancer` | ✅ | ✅ | ✅ | 551 s (amphora build ~2 min) | Load balancer and both members `ONLINE`, TCP monitor `ONLINE`; record written in a zone shared with the project; rule between local security groups |
| `04-complete` | — | — | — | — | Pending |

Public cloud: pending.

### Defects found by the integration tests

| # | Defect | Symptom | Fix |
|---|---|---|---|
| 1 | Empty `availability_zone_hints` sent as `[]` | The provider reads `[]` back as unknown and the attribute forces replacement: **every plan after apply recreated the network**, its subnet, router port and interface | Send `null` when the list is empty (networks and routers) |
| 2 | Root volume created by Nova (`block_device` from image) | Nova did not pass its availability zone to Cinder, which fell back to its default zone: `NoValidBackend`, instance in `ERROR`. The data volume of the same run, created with an explicit zone, succeeded | The module creates the root volume itself, in zone `boot.az` (defaults to the instance zone), and boots from it |

### Environment observations

- Test subnets need DNS resolvers (`dns_nameservers`); without them cloud-init waits for package index timeouts for several minutes.
- An image with `shared` visibility and no members is invisible to a project with the `member` role; administrators do not notice it because the `admin` role sees every image.
