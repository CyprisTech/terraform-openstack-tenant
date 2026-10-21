# terraform-openstack-tenant

OpenTofu / Terraform modules to describe an OpenStack tenant in a single declarative model: networks, routers, security groups, instances, volumes, floating IPs, Octavia load balancers and Designate DNS. Objects created elsewhere can be adopted rather than recreated.

> **Status: under redesign.** The current code predates the design described in [ADR-0001](docs/adr/0001-module-design.md) and will be rewritten in successive pull requests. Do not use it in production yet; `v0.1.0` will be the first supported release.

## Design goals

- **One model per tenant**, maps keyed by name, so that `plan` succeeds in one pass (no `-target`).
- **Two privilege levels**: `modules/cloud-baseline` for cloud administrators (projects, quotas, users, flavors, images, shared networks); the root module for project-scoped resources.
- **Adopt existing objects**: networks, subnets, security groups, DNS zones, volumes.
- **No operational opinion**: no backend, no provider configuration, no secret store dependency. You choose how state, secrets and pipelines are handled.
- **OpenTofu and Terraform** on equal footing, both tested in CI.

## Requirements

| Name | Version |
|---|---|
| OpenTofu or Terraform | >= 1.6 |
| [terraform-provider-openstack/openstack](https://registry.terraform.io/providers/terraform-provider-openstack/openstack) | ~> 3.x (after the redesign) |

## Contributing

- Install the hooks: `pre-commit install` (gitleaks, fmt, tflint).
- Never commit state, plan or `*.tfvars` files: they may contain secrets.
- One logical change per commit, with a message explaining *why*.

## License

[Apache License 2.0](LICENSE).
