# Real-cloud pitfalls

Problems met on real OpenStack clouds while testing this module and [openstack-multitenant-reference](https://github.com/CyprisTech/openstack-multitenant-reference). None of them shows in a mocked test or a successful `plan`; most show as timeouts. Check them before the first apply on a new cloud.

| Symptom | Likely cause | Section |
|---|---|---|
| Small requests work, large replies hang (TLS handshakes, package downloads, API calls) | Path MTU | [MTU](#mtu) |
| First boot takes minutes; cloud-init waits on package indexes | No resolver reachable | [Resolvers](#resolvers-at-first-boot) |
| Security group or allowed range is right, yet connections time out | Source NAT: the target sees a router address | [Source addresses](#source-addresses-behind-routers) |
| A second floating IP answers only some clients | Replies follow the instance routes | [Several floating IPs](#several-floating-ips-and-reply-routing) |
| TLS fails behind a load balancer with the PROXY protocol | Two PROXY headers | [PROXY protocol](#proxy-protocol) |
| `409 OverQuota` on the first security group, or volumes stuck during a replacement | Project quotas | [Quotas](#quotas) |
| An image exists but the project cannot use it | Image visibility | [Images](#images) |
| `apply` fails on a DNS record, the next one fails with `Duplicate RecordSet` | Designate zone pending | [DNS](#dns) |
| Every plan after apply fails with `PortNotFound` on a load balancer | Load balancer in `ERROR` | [operations guide](operations.md#recovering-a-load-balancer-in-error) |

## MTU

Tenant networks often run inside an overlay (VXLAN or Geneve) that may itself run over another tunnel. If a tenant network has a larger MTU than a network its traffic crosses, large packets are dropped, and many virtual routers send no *fragmentation needed* back: small packets pass, large ones vanish.

- Ask the cloud operator for the MTU of tenant networks and of each external network, and set `networks.<key>.mtu` to the smallest value on the path.
- Every overlay inside the tenant (container bridges, Kubernetes pod networks) must subtract its own overhead, for example 50 bytes for VXLAN.
- Seen on the test cloud: tenant networks at 1442 crossing external networks at 1382; fixed with `mtu = 1362` on every tenant network.

## Resolvers at first boot

cloud-init installs packages at first boot. Without a resolver reachable from the subnet, it waits for timeouts: 420 s instead of 20 s on the test cloud. Set `subnets.<key>.dns_nameservers` to resolvers reachable **through the routes of the subnet**; a resolver on a network the instance cannot reach yet is no better than none.

## Source addresses behind routers

A router with source NAT (the default on an external gateway) replaces the instance address with its own external address. A security group, an `allowed_cidrs` list or a firewall on the target sees **the router's address**, not the instance's.

- To admit operators on a bastion, use the address the cloud shows for them (often a router of their own network), not their workstation address.
- On a shared external network, every tenant joining it through a router appears from an address of that network's range: an address of the range identifies no one. Admit specific addresses.

## Several floating IPs and reply routing

With [`extra_floating_ips`](adr/0003-floating-ips-per-port.md), each floating IP arrives through its own router, but **replies leave through the routes of the instance**. A floating IP only serves clients whose addresses are routed back through its router: advertise those ranges with `advertise_routes` on that router. Replies to other clients leave through the default gateway with the wrong source address and are dropped. A client must also be allowed by its own security groups to open the connection (egress rules).

## PROXY protocol

With `pool.protocol = "PROXY"`, Octavia adds a PROXY header so that backends see the client address. **Exactly one header** must reach the backend: when a backend is itself behind another proxy or load balancer that adds a header, TLS fails. Let only the first hop add it, and configure the backend to accept it only from that hop's addresses.

Prefer `TCP` or `HTTP` health monitors to `PING`: a ping proves the instance is up, not that the service answers.

## Quotas

- Some public clouds create projects with **no security group quota** (`security_group = 0`): the first security group fails with `409 OverQuota`, and raising it may need a support request.
- With `boot.source = "volume"`, every instance has a root volume. A rolling replacement creates the new instance before deleting the old one: the volume quota (count and gigabytes) needs room for one more root volume per group being replaced.
- Floating IPs, load balancers and routers have their own quotas; a complete tenant with a load balancer and several planes uses more of them than the instances suggest.

## Images

An image with `shared` visibility is invisible to a project with the `member` role until the project has accepted it as a member. Administrators see every image and do not notice. Use `public` images, or check visibility with the project's own credentials.

## DNS

Designate creates records asynchronously; a zone can stay `PENDING` for minutes when its backend is slow. If `apply` times out on a record, Designate may still create it later, and the next `apply` fails with `Duplicate RecordSet`. Import the record, then plan again:

```bash
tofu import 'module.tenant.module.dns.openstack_dns_recordset_v2.this["<key>"]' '<zone id>/<recordset id>'
```

Records attached to ports and floating IPs live in `modules/instance` (`module.tenant.module.instance["<instance>"]...`); use `tofu state list` to find the address.
