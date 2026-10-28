# Project lifecycle

How changes, releases, decisions and support are handled. It applies to this repository and to [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference), which follow the same rules.

## Versions

- [Semantic Versioning](https://semver.org/). Before `v1.0.0`:
  - a **minor** version (`0.x.0`) may change the interface; the [changelog](../CHANGELOG.md) gives migration notes;
  - a **patch** version (`0.1.x`) fixes defects or adds backward-compatible features; existing configurations and states plan without changes.
- Changes to documentation, examples, tests or CI are published on `main` without a release. They are listed under *Unreleased* in the changelog and ship with the next release.
- `v1.0.0` comes when the interface has been used on at least two different clouds without breaking change for one minor version.

## Changes

1. One change per pull request, from a short-lived branch named after the change (`extra-floating-ips`, not a personal or tool prefix): the name ends up in the merge commit.
2. The pull request describes the context, the changes, the test plan and the risks ([template](../.github/pull_request_template.md)), and is opened as soon as the first commit exists, so that the work can be followed.
3. CI must pass. A change of behaviour comes with a mocked test; a change that the mocked tests cannot see (cloud-side defaults, read-back attributes) comes with an integration stage or an update of one.
4. Documentation is part of the change: [tenant model](tenant-model.md), README reference (`terraform-docs`), changelog entry, and [testing](testing.md) when a real cloud was used.
5. Decisions that change the interface, a dependency, a security boundary, or choose between real alternatives get an [ADR](adr/README.md).

## Decisions (ADRs)

- An ADR is revised in place until the release that implements it. From then on it is not edited: a later decision supersedes it with a new ADR, and the status line of the old one points to the new one.
- `architecture.md` describes the current state; ADRs record why it is so. When they disagree, the newest accepted ADR and the code win, and the documentation is fixed.

## Releases

Release gates, all required:

| Gate | Patch | Minor |
|---|---|---|
| CI green: `fmt`, `validate`, TFLint, mocked tests on OpenTofu and Terraform (lowest supported and latest), examples, gitleaks, Trivy | ✅ | ✅ |
| Integration stages on the reference cloud: apply, **empty plan after apply**, destroy, no leftover | stages touched by the change | all stages and `three-tier-ha` |
| Changelog dated, with migration notes when needed; README compatibility table and roadmap updated | ✅ | ✅ |
| ADRs of the release marked *Accepted* | ✅ | ✅ |
| Downstream check: [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference) validates against the release candidate | when the outputs or a used input change | ✅ |

Steps:

1. A release pull request: changelog section dated, roadmap updated.
2. After merge, an annotated tag `vX.Y.Z` on `main`.
3. `main` and the tag are published; a GitHub Release is created with the changelog section as notes.
4. The registries ([OpenTofu](https://search.opentofu.org/module/cypristech/tenant/openstack), [Terraform](https://registry.terraform.io/modules/CyprisTech/tenant/openstack)) pick the tag up; check that the new version is listed.
5. Downstream repositories move to the new version in their own pull request.

Tags are never moved or deleted once published. A faulty release is fixed by the next patch, and the changelog says which release to skip.

## Support

- Before `v1.0.0`, only the latest minor release receives fixes.
- Security issues follow the [security policy](../SECURITY.md).
- From `v1.0.0`, a feature is deprecated in one minor release (warning in the changelog and in a validation message where possible) before it is removed in the next major.

## Dependencies

- GitHub Actions are pinned by commit and updated by Dependabot.
- The provider constraint (`~> 3.2`) and the minimum OpenTofu and Terraform versions are reviewed at every minor release; CI tests the lowest supported and the latest versions, so a raised minimum is always a deliberate, documented change.
