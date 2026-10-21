# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before `v1.0.0`, minor versions may contain breaking changes; each one comes with migration notes.

## [Unreleased]

### Added

- Repository skeleton: Apache-2.0 license, `.gitignore` blocking state, plan and `tfvars` files, EditorConfig, TFLint and pre-commit configuration (gitleaks, fmt, tflint, terraform-docs).
- CI on GitHub Actions: `fmt`, `init` and `validate` on OpenTofu and Terraform (lowest supported and latest), TFLint, gitleaks over the full history, Trivy configuration scan, README reference check. Actions pinned by commit SHA; Dependabot updates.
- Documentation: README, architecture guide, operations guide, ADR-0001 (module design), contribution guide, Code of Conduct, security policy, support page, issue and pull request templates.

### Changed

- Existing code formatted with `tofu fmt` (no behaviour change).

[Unreleased]: https://github.com/CyprisTech/terraform-openstack-tenant/commits/main
