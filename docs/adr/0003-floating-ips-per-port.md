# ADR-0003: Several floating IPs on one port

- **Status:** Accepted (implemented in `v0.1.2`; recorded 2026-10-28)
- **Date:** 2026-10-27
- **Deciders:** Gregory Gabrielian

## Context

Clouds that separate traffic into several external networks (a public services network, a monitoring network, an intranet) need an instance reachable from more than one of them. The case came from [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference): every instance is published on a services network and exposed to a metrics collector on a monitoring network, without joining a shared monitoring segment. `v0.1.1` allowed one floating IP per port.

Neutron accepts several floating IPs on one fixed address when each external network is reached through its own router on the port's subnet. A test on a private cloud (two floating IPs on one port, each through its own router) passed from routed clients.

## Options considered

1. **A second port per instance on each extra network.** Works without floating IPs, but every tenant joins a shared segment, and the instance needs routes or policy routing per port.
2. **`floating_ip` becomes a list.** Simple to write, but list positions become resource keys: removing one entry shifts the others and recreates their floating IPs, against ADR-0001 (D5).
3. **`floating_ip` unchanged, plus `extra_floating_ips` keyed by a free label** (chosen).

## Decision

- `floating_ip` stays the primary floating IP: its resources, state addresses and DNS record keys do not change, so `v0.1.2` is backward compatible.
- `extra_floating_ips` adds one floating IP per **other** external network, keyed by a label (`monitoring`); resources are keyed `<port>/<label>`. The pools of a port must all differ.
- Outputs: `floating_ips` maps each label to its address ([ADR-0002](0002-output-contract.md)).

## Consequences

- **Replies follow the routes of the instance**, not the router that received the request. An extra floating IP only serves clients whose addresses are routed back through its router; those ranges are advertised to the instance with `advertise_routes`. Replies to other clients leave through the default gateway with the wrong source address and are lost. This is documented in the [tenant model](../tenant-model.md) and the [pitfalls](../pitfalls.md).
- The network design, not the module, decides which ranges each plane serves.
- Integration stage `05-extra-floating-ips` covers the feature on OpenTofu and Terraform.
