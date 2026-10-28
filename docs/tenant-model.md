# Tenant model reference

This page documents every attribute of the `tenant` variable of the composite module, and the inputs of the building blocks. The design behind it is in [ADR-0001](adr/0001-module-design.md). Examples live in [`examples/`](../examples/README.md).

> [!NOTE]
> Status: released in `v0.1.0` (mocked tests on OpenTofu and Terraform; integration tests on a private OpenStack cloud, see [testing.md](testing.md)). The interface is declared in [`variables.tf`](../variables.tf).

## Conventions

- **Collections are maps keyed by name.** The key identifies the object everywhere: `instances.web-1`, `networks.app.subnets.main`. Keys are also the default OpenStack names.
- **References use keys**, never IDs: a port names its `network` and `subnet`, a router names its `external_network`, a pool lists `members` as `"<instance>.<port>"`.
- **Local and adopted objects share one namespace.** A reference to `networks.app` or `existing.networks.app` is written the same way: `network = "app"`. Using the same key in both is an error.
- **Optional attributes** are marked *optional*; their default is given when there is one.
- **Exactly one of** means that the plan fails if none or both are set.

## Top-level attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| [`existing`](#existing) | object | `{}` | Objects owned elsewhere, adopted by ID or name |
| [`networks`](#networks) | map | `{}` | Networks, subnets and routers created in the project |
| [`security_groups`](#security_groups) | map | `{}` | Security groups and their rules |
| [`server_groups`](#server_groups) | map | `{}` | Nova server groups (anti-affinity...) referenced by instances |
| [`instances`](#instances) | map | `{}` | Instances, their ports, volumes and DNS records |
| [`load_balancers`](#load_balancers) | map | `{}` | Octavia load balancers (requires Octavia) |
| [`dns`](#dns) | object | `{}` | Zones and free-form records (requires Designate) |
| [`defaults`](#defaults) | object | `{}` | Defaults applied across the model |

## Project

The composite creates nothing at the project level: all resources go to the **project of the provider's credentials**, and a member role is enough. Projects, quotas and role assignments are created by `cloud-baseline` (`v0.2.0`). Nova cannot create instances in another project than the token's, so a composite creating its own project could not place its instances in it.

## `existing`

Objects created by another stack, another team or the console. Networks, subnets and security groups are given **by exactly one of `id` or `name`**; DNS zones always give their `name` (it builds record names) and optionally their `id`:

- with `id`, nothing is looked up: the ID may come from another module in the same configuration, even if that object is created in the same apply;
- with `name`, a data source resolves the object at plan time: it must already exist and be visible from the project.

| Attribute | Type | Description |
|---|---|---|
| `networks.<key>.id` / `.name` | string | Network to adopt |
| `networks.<key>.subnets.<key>.id` / `.name` | string | Subnets of that network that the model references (router gateways, ports) |
| `security_groups.<key>.id` / `.name` | string | Security group to adopt, typically from a shared catalog |
| `dns_zones.<key>.name` | string | Zone name with its trailing dot (required) |
| `dns_zones.<key>.id` | string | Zone ID; optional, avoids the lookup by name |

> [!IMPORTANT]
> A DNS zone is usable only if the project **owns** it or if it is **shared** with the project. Zones should be created *for* a project or shared with it by the administrator; transferring a zone after creation hides it from the stack that created it.

## `networks`

Map key: network name (unless `name` is set).

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | string | key | OpenStack name |
| `mtu` | number | cloud default | MTU of the network. Set it to the smallest MTU on the path when the network's traffic crosses other networks or tunnels ([pitfalls](pitfalls.md#mtu)) |
| `admin_state_up` | bool | `true` | |
| `availability_zone_hints` | list(string) | `[]` | |
| `subnets` | map | required | See below |
| `routers` | map | `{}` | See below |

**`subnets.<key>`**

| Attribute | Type | Default | Description |
|---|---|---|---|
| `cidr` | string | required | Subnet range |
| `ip_version` | number | `4` | |
| `gateway_ip` | string | first address | |
| `enable_dhcp` | bool | `true` | |
| `dns_nameservers` | list(string) | `[]` | Resolvers pushed by DHCP; they must be reachable through the routes of the subnet at first boot ([pitfalls](pitfalls.md#resolvers-at-first-boot)) |
| `allocation_pools` | list({start, end}) | whole range | Addresses DHCP may allocate |
| `host_routes` | list({destination, nexthop}) | `[]` | Static routes pushed by DHCP |

**`routers.<key>`** — one router connects one subnet of this network to one external network. Several routers per network let each one reach a different network plane.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `external_network` | string | required | Key in `existing.networks` |
| `external_subnet` | string | any | Key of the external subnet for the gateway |
| `external_ip` | string | allocated | Fixed gateway address on the external network |
| `internal_subnet` | string | required | Key of the subnet of this network |
| `internal_ip` | string | see below | Fixed router address on the internal subnet |
| `default_gateway` | bool | see below | Give this router the subnet's gateway address |
| `advertise_routes` | list(string) | `[]` | Destinations pushed to the internal subnet as host routes via this router |
| `admin_state_up` | bool | `true` | |
| `availability_zone_hints` | list(string) | `[]` | |

**Default gateway.** Instances use the subnet's gateway address as default route. When no router of a subnet sets `internal_ip` or `default_gateway`, the **first router of that subnet in key order** takes the gateway address; the others get an allocated address and are reached through `advertise_routes`. Set `default_gateway = true` on another router to choose it, or manage every address with `internal_ip`.

## `security_groups`

Map key: security group name.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `description` | string | `""` | |
| `rules.<key>.direction` | string | required | `"ingress"` or `"egress"` |
| `rules.<key>.ethertype` | string | `"IPv4"` | |
| `rules.<key>.protocol` | string | any | `"tcp"`, `"udp"`, `"icmp"`... |
| `rules.<key>.port_min` / `port_max` | number | all | Port range |
| `rules.<key>.remote_ip_prefix` | string | — | Source or destination CIDR |
| `rules.<key>.remote_group` | string | — | Key of a local or existing security group, instead of a CIDR |

Rules are keyed by name, so adding or removing one never recreates the others.

## `server_groups`

Map key: server group name. Instances reference a group with `server_group`.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `policy` | string | `"anti-affinity"` | `anti-affinity` (members on different hosts, scheduling fails otherwise), `affinity`, `soft-anti-affinity` (spread when possible), `soft-affinity` |
| `max_server_per_host` | number | — | With `anti-affinity` only: allow up to N members per host |

> [!TIP]
> Prefer `soft-anti-affinity` when the cloud may have fewer hosts than replicas: hard `anti-affinity` makes the extra instances fail to schedule.

## `instances`

Map key: instance name.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `az` | string | required | Availability zone |
| `flavor` / `flavor_id` | string | — | **Exactly one of**: flavor name or ID |
| `image` / `image_id` | string | — | Image name or ID; required unless `boot.source = "existing"` |
| `boot` | object | `{ source = "image" }` | See below |
| `server_group` | string | — | Key in `server_groups` |
| `ports` | map | required | See below |
| `volumes` | map | `{}` | See below |
| `user_data` | string | `null` | Cloud-init data, for example from `modules/cloudinit` |
| `labels` | list(string) | `[]` | Free labels, exposed in outputs and metadata for the layers above |
| `metadata` | map(string) | `{}` | Additional instance metadata |

**`boot`** — how the root disk is provided, selected by `source`:

| `source` | Attributes | Behaviour |
|---|---|---|
| `"image"` | — | Ephemeral root disk from the image |
| `"volume"` | `size`, `volume_type`, `az` | Root volume created from the image **by the module**, in Cinder zone `az` (defaults to the instance zone, which may differ from Cinder's); a newer image never recreates it |
| `"existing"` | exactly one of `id`, `name` | Boot from an existing volume, for example to rebuild an instance on its surviving disk |

**`ports.<key>`** — the first port in key order is the primary interface. A second port on another network (management, storage, backup) is just another entry; to add the same port to every instance, merge it in the caller (see [`examples/adopt-existing`](../examples/adopt-existing)).

| Attribute | Type | Default | Description |
|---|---|---|---|
| `network` / `subnet` | string | required | Keys in `networks` or `existing.networks` |
| `fixed_ip` | string | allocated | Fixed address |
| `security_groups` | list(string) | `[]` | Keys of local or existing security groups |
| `floating_ip.pool` | string | — | Key in `existing.networks` of the external network providing the floating IP |
| `floating_ip.subnet` | string | any | Key of a subnet of that network |
| `floating_ip.dns` | list({name, zone}) | `[]` | A records on the floating IP; `zone` is a key in `dns.zones` or `existing.dns_zones` |
| `extra_floating_ips.<label>` | object | `{}` | More floating IPs on the same port, keyed by a free label (for example `monitoring`); same attributes as `floating_ip`: `pool`, `subnet`, `dns` |
| `dns` | list({name, zone}) | `[]` | A records on the fixed IP |

**Several floating IPs on one port.** `floating_ip` stays the primary floating IP; `extra_floating_ips` adds one floating IP per *other* external network. The pools of `floating_ip` and of every `extra_floating_ips` entry of a port must all differ, and each pool must be a key of `existing.networks`. Neutron accepts several floating IPs on one fixed address only when each external network is reached through its own router on the port's subnet (see [`routers`](#networks)).

> [!IMPORTANT]
> Replies leave through the **instance routes**, not through the router that received the request. An extra floating IP only serves clients whose addresses are routed back through its external network's router: advertise those ranges with `advertise_routes` on that router (for example the monitoring plane range). Replies to other clients leave through the default gateway, with the wrong source address, and never reach them.

**`volumes.<key>`** — data volumes attached to the instance.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `size` | number | — | Size in GiB, for a volume created by the module |
| `az` | string | instance AZ | |
| `volume_type` | string | cloud default | |
| `existing` | object | — | Exactly one of `id`, `name`: attach an existing volume instead of creating one |

> [!IMPORTANT]
> The module sets no `prevent_destroy`: Terraform does not allow lifecycle rules to depend on variables. Data that must survive the instance belongs in a volume created and protected outside the module, then attached with `existing`.

> [!NOTE]
> Changes to `user_data`, to the image (including a newer image published under the same name) and to `boot` are ignored on existing instances. To apply them, replace the instance explicitly with `-replace`.

## `load_balancers`

Requires Octavia. Map key: load balancer name.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `vip.network` / `vip.subnet` | string | required | Keys in `networks` or `existing.networks` |
| `vip.ip` | string | allocated | Fixed virtual IP |
| `flavor_id` | string | cloud default | Octavia flavor. The **topology** (single amphora or active/standby pair) and the amphora size are defined by flavors created by the cloud administrator: `openstack loadbalancer flavor list` |
| `availability_zone` | string | cloud default | Octavia availability zone |
| `security_groups` | list(string) | `[]` | Keys of local or existing security groups applied to the VIP port |
| `floating_ip` | object | — | Same attributes as a port's `floating_ip` |
| `listeners.<key>.protocol` / `port` | string / number | required | For example `"TCP"` 443, `"HTTP"` 80 |
| `listeners.<key>.allowed_cidrs` | list(string) | `[]` | Source restriction |
| `listeners.<key>.timeouts` | map(number) | `{}` | `client_data`, `member_connect`, `member_data`, `tcp_inspect` (ms) |
| `listeners.<key>.pool.protocol` | string | required | For example `"PROXY"` to pass client addresses to backends |
| `listeners.<key>.pool.method` | string | `"ROUND_ROBIN"` | |
| `listeners.<key>.pool.members` | list(string) | required | `"<instance>.<port>"` |
| `listeners.<key>.pool.member_port` | number | listener port | |
| `listeners.<key>.pool.monitor` | object | — | `type` (`"TCP"`, `"HTTP"`, `"PING"`...), `delay` 5, `timeout` 3, `max_retries` 3, `url_path`, `expected_codes` |

## `dns`

Requires Designate.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `zones.<key>.name` | string | required | Zone name, ending with a dot; created and owned by the project |
| `zones.<key>.email` | string | required | Contact address |
| `zones.<key>.ttl` | number | `defaults.ttl` | |
| `zones.<key>.description` | string | `""` | |
| `records.<key>.zone` | string | required | Key in `dns.zones` or `existing.dns_zones` |
| `records.<key>.name` | string | required | Relative name; `""` for the zone apex |
| `records.<key>.type` | string | required | `A`, `AAAA`, `CNAME`, `MX`, `TXT`... |
| `records.<key>.records` | list(string) | required | Values |
| `records.<key>.ttl` | number | `defaults.ttl` | |

## `defaults`

| Attribute | Type | Default | Description |
|---|---|---|---|
| `ttl` | number | `3000` | TTL of DNS records when not set |

## Outputs

The composite exposes outputs keyed like the input, with a fixed shape (absent values are `null`) and no OpenStack-specific notion. The contract will be formalised in a dedicated ADR; the implemented shape is:

| Output | Content |
|---|---|
| `instances` | `<name> => { id, az, labels, ports = { <port> => { id, ip, floating_ip, floating_ips, fqdn } } }`; `floating_ips` maps each `extra_floating_ips` label to its address (`{}` when none) |
| `server_groups` | `<name> => { id, policy }` |
| `networks` | `<name> => { id, subnets = { <subnet> => { id, cidr } }, routers = { <router> => { id, internal_ip } } }` |
| `security_groups` | `<name> => { id }` |
| `load_balancers` | `<name> => { id, vip, floating_ip, fqdns }` |
| `dns_zones` | `<name> => { id, name }` |

## Building blocks

The building blocks take **IDs** instead of keys: wiring them together is the caller's code (see [`examples/building-blocks`](../examples/building-blocks)). Their interfaces mirror the matching slice of the model:

| Module | Main inputs | Main outputs |
|---|---|---|
| [`modules/network`](../modules/network) ✅ | `name`, `project_id`, `mtu`, `subnets` (as above), `routers` with `external_network_id`, `external_subnet_id`, `external_ip`, `internal_subnet`, `internal_ip`, `advertise_routes` | `id`, `name`, `subnets`, `routers` |
| [`modules/security-group`](../modules/security-group) ✅ | `name`, `description`, `project_id`, `delete_default_rules`, `rules` with `remote_group_id` (an ID, or `"self"`) instead of `remote_group` | `id`, `name`, `rule_ids` |
| [`modules/instance`](../modules/instance) ✅ | `name`, `project_id`, `az`, `flavor` / `flavor_id`, `image` / `image_id`, `boot`, `ports` with `network_id`, `subnet_id`, `fixed_ip`, `security_group_ids`, `port_security_enabled`, `allowed_address_pairs`, `floating_ip` (`pool`, `subnet_id`, `dns`), `extra_floating_ips` (map of the same shape) and `dns` (entries `{ name, zone_id, zone_name, ttl }`); `volumes`; `user_data`; `key_pair`; `server_group_id`; `labels`; `metadata`; `default_ttl` | `id`, `name`, `az`, `labels`, `ports`, `volumes` |
| [`modules/loadbalancer`](../modules/loadbalancer) ✅ | `name`, `project_id`, `vip` (`subnet_id`, `address`), `flavor_id`, `availability_zone`, `security_group_ids`, `floating_ip` (`pool`, `subnet_id`, `dns`), `listeners` with `pool.members` keyed by name as `{ address, subnet_id, port, weight, backup }`; `default_ttl` | `id`, `vip`, `floating_ip`, `fqdns`, `listeners` |
| [`modules/dns`](../modules/dns) ✅ | `project_id` (admin: create zones *for* a project), `zones`, `records` with `zone` (local key) or `zone_id` + `zone_name`; `default_ttl` | `zones`, `records` |
| [`modules/cloudinit`](../modules/cloudinit) ✅ | `hostname`, `fqdn`, `timezone`, `users`, `packages`, `package_update`, `package_upgrade`, `disks`, `bind_mounts`, `write_files`, `runcmd`, `extra_config` | `rendered`, `config` |

✅ = implemented. Exact inputs are documented in each module's README.
