# Contributing

Thank you for considering a contribution. This guide explains how to set up a development environment, the conventions the code follows, and how changes are reviewed.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** or **request a feature** with the [issue templates](https://github.com/CyprisTech/terraform-openstack-tenant/issues/new/choose).
- **Improve the documentation**: typos, unclear explanations, missing examples.
- **Submit code**: open an issue first for anything larger than a small fix, so the design can be agreed before you invest time. Significant design changes need an [ADR](docs/adr/README.md).

## Development setup

| Tool | Purpose | Version |
|---|---|---|
| [OpenTofu](https://opentofu.org/docs/intro/install/) and/or [Terraform](https://developer.hashicorp.com/terraform/install) | validate and test | >= 1.9 |
| [TFLint](https://github.com/terraform-linters/tflint) | lint | latest |
| [terraform-docs](https://terraform-docs.io) | generate the README reference | >= 0.19 |
| [pre-commit](https://pre-commit.com) | run checks before each commit | latest |
| [gitleaks](https://github.com/gitleaks/gitleaks) | detect secrets | installed by pre-commit |

```bash
git clone https://github.com/CyprisTech/terraform-openstack-tenant.git
cd terraform-openstack-tenant
pre-commit install
```

## Checks

Run the same checks as CI before pushing:

```bash
tofu fmt -check -recursive          # or: terraform fmt -check -recursive
tofu init -backend=false && tofu validate
tflint --init && tflint --recursive
terraform-docs .                    # README reference must be up to date
tofu test                           # mocked tests, no cloud required
pre-commit run --all-files          # everything above plus gitleaks
```

Integration tests against a real OpenStack cloud are run by the maintainers on dedicated test infrastructure; they are not required from contributors.

## Coding conventions

These rules come from [ADR-0001](docs/adr/0001-module-design.md):

- **Stable keys.** Use `for_each` over maps keyed by names from the input. Never derive a key or a `for_each` collection from an attribute known only after apply (`id`, `device_id`, addresses).
- **Fixed-shape outputs.** Outputs always have the same attributes; use `null` for absent values rather than conditional `merge`.
- **No provider or backend blocks** in any module. Declare `required_providers` in `versions.tf` only.
- **No site-specific defaults.** Defaults must be valid on any OpenStack cloud. Add `validation` blocks for formats and cross-references.
- **Secrets.** Mark every secret input and output `sensitive`. Never put secrets in `user_data`, examples or tests.
- **Typed variables.** Use `object({...})` with `optional()` attributes and a `description` on every variable and output.
- **Documentation in code.**
  - Every variable and output has a `description`; for object types, the description explains each attribute (the type alone does not say what a field means). TFLint enforces it.
  - Comments explain **why**, only where the code would surprise a reader: fixed `lifecycle` rules, how `for_each` keys are built, provider workarounds, privilege-related headers. Do not paraphrase what the HCL already says.
- **Formatting.** `tofu fmt`; two-space indentation; files named by concern (`networks.tf`, `instances.tf`...).

## Commits

- One logical change per commit.
- Subject in the imperative mood, at most 72 characters (`Add router host routes`, not `added routes`).
- A body that explains **why** the change is needed when it is not obvious.
- Disclose AI assistance with a `Co-Authored-By:` trailer.
- Never commit state, plan or `*.tfvars` files.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your change with tests and documentation (README reference, examples, changelog entry under *Unreleased*).
3. Open a pull request and fill in the template.
4. CI must pass on OpenTofu and Terraform.
5. A maintainer reviews the change. Breaking changes are accepted only with a changelog entry and migration notes.

## Release process

Maintainers tag releases from `main` following [Semantic Versioning](https://semver.org/):

1. Move the *Unreleased* entries of [CHANGELOG.md](CHANGELOG.md) under the new version with its date.
2. Tag `vX.Y.Z` and publish a GitHub release with the changelog section.

## License

By contributing, you agree that your contributions are licensed under the [Apache License 2.0](LICENSE).
