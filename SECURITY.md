# Security policy

## Supported versions

| Version | Supported |
|---|---|
| Latest minor release | Yes |
| Older releases | No — upgrade to the latest minor release |
| `main` before `v0.1.0` | Best effort (pre-release) |

## Reporting a vulnerability

**Do not open a public issue.** Report privately through GitHub's [private vulnerability reporting](https://github.com/CyprisTech/terraform-openstack-tenant/security/advisories/new). If you cannot use it, email [opensource@cypris-tech.com](mailto:opensource@cypris-tech.com).

Please include:

- the affected version or commit;
- a description of the issue and its impact (for example, a secret written to an unexpected place, an overly permissive default, a resource created with a broader scope than declared);
- a minimal configuration that reproduces it, **with all credentials, addresses and names replaced by placeholders**.

Never send state files, plan files, `clouds.yaml`, application credentials or real infrastructure details.

## What to expect

| Step | Target |
|---|---|
| Acknowledgement | within 5 business days |
| Initial assessment | within 10 business days |
| Fix or mitigation | depends on severity; critical issues are prioritised |
| Disclosure | coordinated with the reporter, through a GitHub security advisory once a fix is released |

## Scope

In scope: the modules in this repository, their default values and the examples.

Out of scope: vulnerabilities in OpenStack itself, in the OpenStack provider, in OpenTofu or Terraform (report them to the respective projects), and the way an operator stores state or secrets (see [docs/operations.md](docs/operations.md)).

## Security-relevant behaviour of the modules

- Generated passwords are stored in the state until the OpenStack provider supports write-only attributes. Treat every state file as a secret.
- Secret inputs and outputs are marked `sensitive`, which hides them from CLI output only.
- Sharing security groups with every project (`share_with = ["*"]`) is never a default; it must be declared.
