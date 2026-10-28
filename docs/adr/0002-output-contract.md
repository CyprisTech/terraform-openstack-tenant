# ADR-0002: Output contract of the tenant composite

- **Status:** Accepted (implemented in `v0.1.0`, extended in `v0.1.2`; recorded 2026-10-28)
- **Date:** 2026-10-28
- **Deciders:** Gregory Gabrielian
- **Fulfils:** [ADR-0001](0001-module-design.md), D11 (the contract was to be specified in its own ADR)

## Context

ADR-0001 (D11) promised a provider-neutral output contract, specified separately. The outputs were implemented in `v0.1.0` and extended in `v0.1.2`, but the contract was only described in comments and descriptions. Upper layers now depend on it: [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference) builds its routes, monitoring targets and inventories from `instances`, `load_balancers` and `networks`. Without a written contract, a change of shape can break them in a release that looks harmless.

## Options considered

1. **Expose the resources** (whole `openstack_*` objects). Complete, but every consumer depends on the provider's schema, and a provider upgrade can change the outputs.
2. **Free-form outputs per release.** Simple, but no stability rule: consumers cannot know what they may rely on.
3. **A fixed, documented shape keyed like the input, with a compatibility rule** (chosen).

## Decision

### What the contract contains

| Output | Shape |
|---|---|
| `instances` | `<key> => { id, az, labels, ports = { <port> => { id, ip, floating_ip, floating_ips, fqdn } } }` |
| `networks` | `<key> => { id, subnets = { <subnet> => { id, cidr } }, routers = { <router> => { id, internal_ip } } }` (created networks only) |
| `security_groups` | `<key> => { id }` (created groups only) |
| `load_balancers` | `<key> => { id, vip, floating_ip, fqdns }` |
| `dns_zones` | `<key> => { id, name }` (created zones only) |
| `server_groups` | `<key> => { id, policy }` |

### Rules

1. **Keyed like the input.** The keys are those of the `tenant` variable; a consumer finds an object by the name it gave it.
2. **Fixed shape.** Every attribute is always present; an absent value is `null` (`floating_ip`, `fqdn`) or an empty map (`floating_ips`). No attribute depends on a condition.
3. **No provider schema.** Values are addresses, names, labels and opaque identifiers. Identifiers are strings to pass back to the same cloud (for adoption through `existing`), never parsed.
4. **Compatibility.** Adding an attribute is backward compatible (patch or minor release). Renaming or removing one, or changing its type or meaning, is a breaking change: before `v1.0.0` in a minor release with migration notes, from `v1.0.0` in a major release.
5. **Adopted objects are not repeated.** `networks`, `security_groups` and `dns_zones` list what the module created; adopted objects belong to their owner's outputs.

### Provider neutrality

The shape uses no OpenStack-specific notion: instances with ports and addresses, networks with subnets and routers, load balancers with a virtual address, DNS names. An equivalent module for another cloud can expose the same contract, so that layers built on it (configuration, Kubernetes bootstrap, inventories) do not change. This is a design rule, not a delivered feature: no such module exists yet.

## Consequences

- Consumers may rely on every attribute of the table; the [tenant model reference](../tenant-model.md#outputs) and the output descriptions repeat it.
- A new output attribute needs a mocked test of its shape and a changelog entry.
- Resources whose attributes are not in the contract are reached through the building blocks, which keep their own outputs.
