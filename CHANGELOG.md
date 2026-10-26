# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before `v1.0.0`, minor versions may contain breaking changes; each one comes with migration notes.

## [Unreleased]

### Added

- Integration tests on a real OpenStack cloud (`tests/integration/`), with a summary per run.
- Routers: `default_gateway`; when no router of a subnet sets an address, the first router in key order takes the subnet's gateway address.
- Composite validation of subnet, VIP and management port references.
- Documentation: implementation map and known limitations in the architecture guide; README usage rewritten for the implemented interface.
- Tenant composite (root module): resolves keys to IDs for adopted and created objects, calls the building blocks, creates rules between local security groups, adds the management port, wires load balancer members to instance ports, and exposes the provider-neutral output contract (`instances`, `networks`, `security_groups`, `load_balancers`, `dns_zones`). Mocked test of a single plan on a complete tenant.
- CI validates every example on both tools; TFLint runs recursively, warnings included.
- Building blocks `modules/loadbalancer` (Octavia load balancer, listeners, pools, members keyed by name, health monitors, floating IP and DNS records on the VIP) and `modules/dns` (zones, optionally created for a project, and record sets in local, owned or shared zones), with mocked tests.
- Module `modules/cloudinit`: cloud-config rendering (hostname, users, packages, files, commands); data disks handled by idempotent systemd units that wait for the device, format only when empty, refuse partitioned devices and mount by label at every boot; bind mounts; tests.
- Building block `modules/instance`: ports keyed by name (security groups, allowed address pairs, optional port security), boot from image, new volume or existing volume, created or attached data volumes, floating IPs, DNS records on fixed and floating addresses; fixed lifecycle rules; mocked tests.
- Building blocks `modules/network` (network, subnets, routers attached through dedicated ports, host routes and advertised routes) and `modules/security-group` (rules keyed by name, `self` references), with mocked tests on OpenTofu and Terraform.
- Specification of the `v0.1.0` interface: the composite's `tenant` variable with validation rules, a hand-written tenant model reference (`docs/tenant-model.md`) and six examples (`examples/`).
- Repository skeleton: Apache-2.0 license, `.gitignore` blocking state, plan and `tfvars` files, EditorConfig, TFLint and pre-commit configuration (gitleaks, fmt, tflint, terraform-docs).
- CI on GitHub Actions: `fmt`, `init` and `validate` on OpenTofu and Terraform (lowest supported and latest), TFLint, gitleaks over the full history, Trivy configuration scan, README reference check. Actions pinned by commit SHA; Dependabot updates.
- Documentation rules for code (descriptions on every variable and output, enforced by TFLint; comments explain why).
- Documentation: README, architecture guide, operations guide, ADR-0001 (module design), contribution guide, Code of Conduct, security policy, support page, issue and pull request templates.

### Changed

- Instances booting from a new volume: the root volume is created by the module with an explicit Cinder availability zone (`boot.az`), instead of by Nova, which may not pass its zone to Cinder. Found by integration tests.
- Empty `availability_zone_hints` are sent as null; the provider read them back as unknown and recreated networks and routers on every plan. Found by integration tests.
- The composite no longer creates its project (`project`, `role_assignments` removed): Nova creates instances only in the project of the token. Project creation belongs to `cloud-baseline`.
- Adopted DNS zones always give their `name` (it builds record names); `id` is optional.
- `floating_ip.pool` is a key of `existing.networks`, like every other reference.
- Load balancers take an Octavia `flavor_id` instead of a `topology`: Octavia defines the topology in flavors, not on the load balancer.

### Removed

- The pre-redesign code; it remains available in the history.

[Unreleased]: https://github.com/CyprisTech/terraform-openstack-tenant/commits/main
