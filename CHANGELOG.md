# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before `v1.0.0`, minor versions may contain breaking changes; each one comes with migration notes.

## [Unreleased]

### Fixed

- Minimum versions: OpenTofu and Terraform `>= 1.9`, not `>= 1.6`. The building blocks use a variable validation that refers to another variable, which both tools support from 1.9; `v0.1.0` declared 1.6 and failed to validate on 1.6 to 1.8.
- `modules/loadbalancer`: a listener without health monitor failed validation on versions that evaluate both sides of `||` (OpenTofu 1.9, Terraform 1.9).
- `modules/instance` README reference: regenerated (root volume resource, `boot.az`).
- CI: mocked tests also run on the lowest supported versions.

## [0.1.0] - 2026-10-26

First release: the tenant layers (building blocks, composite, output contract), tested with mocked providers on OpenTofu and Terraform and on a private OpenStack 2025.1 cloud.

### Added

- Example `three-tier-ha`: web, application and data tiers isolated by security groups, bastion, Octavia with PROXY protocol, anti-affinity server groups, data volumes, an inventory output for the configuration layer, and a README explaining the decisions and their trade-offs.
- Server groups in the composite (`server_groups`, `instances.*.server_group`): anti-affinity, affinity, soft variants, `max_server_per_host`.
- Integration tests on a real OpenStack cloud (`tests/integration/`), with a summary per run.
- Routers: `default_gateway`; when no router of a subnet sets an address, the first router in key order takes the subnet's gateway address.
- Composite validation of subnet and VIP references.
- Documentation: implementation map and known limitations in the architecture guide; README usage rewritten for the implemented interface.
- Tenant composite (root module): resolves keys to IDs for adopted and created objects, calls the building blocks, creates rules between local security groups, wires load balancer members to instance ports, and exposes the provider-neutral output contract (`instances`, `networks`, `security_groups`, `load_balancers`, `dns_zones`). Mocked test of a single plan on a complete tenant.
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

- `management_port` and `instances.*.management_port` / `management_egress`: a site convention rather than a general feature. A second port is declared in `ports`; see `examples/adopt-existing` for adding the same port to every instance.
- The pre-redesign code; it remains available in the history.

[Unreleased]: https://github.com/CyprisTech/terraform-openstack-tenant/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/CyprisTech/terraform-openstack-tenant/releases/tag/v0.1.0
