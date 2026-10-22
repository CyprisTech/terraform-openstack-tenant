# Examples

Each example is a complete root configuration. Credentials come from `clouds.yaml`; select the cloud with `OS_CLOUD`.

> [!NOTE]
> These examples are the **specification** of the `v0.1.0` interface. They become executable as the modules are implemented, and each one is then part of the test suite.

| Example | Shows | Credentials | Services |
|---|---|---|---|
| [`minimal-no-lb-no-dns`](minimal-no-lb-no-dns) | The smallest useful tenant | Project member | Nova, Neutron |
| [`lab-single-stack`](lab-single-stack) | A complete tenant that creates its own project, with cloud-init | Admin | + Cinder |
| [`adopt-existing`](adopt-existing) | Adoption by ID and by name of networks, security groups, DNS zones and volumes; management port; boot from an existing volume | Project member | + Cinder, Designate |
| [`layered-network-compute`](layered-network-compute) | Long-lived network layer and short-lived compute layer in separate states | Project member | Nova, Neutron |
| [`public-edge`](public-edge) | Octavia in front of two reverse proxies, PROXY protocol, DNS on the floating IP | Project member | + Octavia, Designate |
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

Adapt names (external network, flavors, images) to your cloud: they differ between providers.
