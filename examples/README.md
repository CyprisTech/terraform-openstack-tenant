# Examples

Each example is a complete root configuration. Credentials come from `clouds.yaml`; select the cloud with `OS_CLOUD`.

> [!NOTE]
> Every example is validated in CI with OpenTofu and Terraform. [`three-tier-ha`](three-tier-ha) has also been applied on a real OpenStack cloud; the building blocks used by the others are covered by the [integration tests](../docs/testing.md).

| Example | Shows | Credentials | Services |
|---|---|---|---|
| [`minimal-no-lb-no-dns`](minimal-no-lb-no-dns) | The smallest useful tenant | Project member | Nova, Neutron |
| [`lab-single-stack`](lab-single-stack) | A complete tenant in one stack, with cloud-init, volumes and floating IPs | Project member | + Cinder |
| [`adopt-existing`](adopt-existing) | Adoption by ID and by name of networks, security groups, DNS zones and volumes; an extra management port; boot from an existing volume | Project member | + Cinder, Designate |
| [`layered-network-compute`](layered-network-compute) | Long-lived network layer and short-lived compute layer in separate states | Project member | Nova, Neutron |
| [`public-edge`](public-edge) | Octavia in front of two reverse proxies on two hosts, PROXY protocol, DNS on the floating IP | Project member | + Octavia, Designate |
| [`three-tier-ha`](three-tier-ha) | Reference architecture: isolated web/app/data tiers, bastion, load balancer, anti-affinity server groups, data volumes, decisions and trade-offs | Project member | + Cinder, Octavia, Designate (optional) |
| [`building-blocks`](building-blocks) | The building blocks used directly, without the composite | Project member | Nova, Neutron |

## Running an example

```bash
export OS_CLOUD=mycloud
cd examples/minimal-no-lb-no-dns
tofu init          # or: terraform init
tofu plan
tofu apply
tofu destroy
```

Adapt names (external network, flavors, images, availability zones) to your cloud: they differ between providers. Before the first apply on a new cloud, read [real-cloud pitfalls](../docs/pitfalls.md).

A complete multi-tenant architecture built on the composite is [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference).
