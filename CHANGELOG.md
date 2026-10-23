# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before `v1.0.0`, minor versions may contain breaking changes; each one comes with migration notes.

## [Unreleased]

### Added

- Building block `modules/instance`: ports keyed by name (security groups, allowed address pairs, optional port security), boot from image, new volume or existing volume, created or attached data volumes, floating IPs, DNS records on fixed and floating addresses; fixed lifecycle rules; mocked tests.
- Building blocks `modules/network` (network, subnets, routers attached through dedicated ports, host routes and advertised routes) and `modules/security-group` (rules keyed by name, `self` references), with mocked tests on OpenTofu and Terraform.
- Specification of the `v0.1.0` interface: the composite's `tenant` variable with validation rules, a hand-written tenant model reference (`docs/tenant-model.md`) and six examples (`examples/`).
- Repository skeleton: Apache-2.0 license, `.gitignore` blocking state, plan and `tfvars` files, EditorConfig, TFLint and pre-commit configuration (gitleaks, fmt, tflint, terraform-docs).
- CI on GitHub Actions: `fmt`, `init` and `validate` on OpenTofu and Terraform (lowest supported and latest), TFLint, gitleaks over the full history, Trivy configuration scan, README reference check. Actions pinned by commit SHA; Dependabot updates.
- Documentation rules for code (descriptions on every variable and output, enforced by TFLint; comments explain why).
- Documentation: README, architecture guide, operations guide, ADR-0001 (module design), contribution guide, Code of Conduct, security policy, support page, issue and pull request templates.

### Removed

- The pre-redesign code; it remains available in the history.

[Unreleased]: https://github.com/CyprisTech/terraform-openstack-tenant/commits/main
