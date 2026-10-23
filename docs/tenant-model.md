# Tenant model reference

This page documents every attribute of the `tenant` variable of the composite module, and the inputs of the building blocks. The design behind it is in [ADR-0001](adr/0001-module-design.md). Examples live in [`examples/`](../examples/README.md).

> [!NOTE]
> Status: specification for `v0.1.0`. The interface is declared in [`variables.tf`](../variables.tf); the modules that implement it are being written.

## Conventions

- **Collections are maps keyed by name.** The key identifies the object everywhere: `instances.web-1`, `networks.app.subnets.main`. Keys are also the default OpenStack names.
- **References use keys**, never IDs: a port names its `network` and `subnet`, a router names its `external_network`, a pool lists `members` as `"<instance>.<port>"`.
- **Local and adopted objects share one namespace.** A reference to `networks.app` or `existing.networks.app` is written the same way: `network = "app"`. Using the same key in both is an error.
- **Optional attributes** are marked *optional*; their default is given when there is one.
- **Exactly one of** means that the plan fails if none or both are set.

## Top-level attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| [`project`](#project) | object | `{}` | Project creation, for labs only |
| [`role_assignments`](#role_assignments) | map | `{}` | Roles on the created project, for labs only |
| [`existing`](#existing) | object | `{}` | Objects owned elsewhere, adopted by ID or name |
| [`networks`](#networks) | map | `{}` | Networks, subnets and routers created in the project |
| [`security_groups`](#security_groups) | map | `{}` | Security groups and their rules |
| [`management_port`](#management_port) | object | `null` | Optional dedicated management network for instances |
| [`instances`](#instances) | map | `{}` | Instances, their ports, volumes and DNS records |
| [`load_balancers`](#load_balancers) | map | `{}` | Octavia load balancers (requires Octavia) |
| [`dns`](#dns) | object | `{}` | Zones and free-form records (requires Designate) |
| [`defaults`](#defaults) | object | `{}` | Defaults applied across the model |

## `project`

By default the module creates nothing at the project level: all resources go to the **project of the provider's credentials**, and a member role is enough. Set `create = true` only for labs, with admin credentials.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `create` | bool | `false` | Create the project and set its quotas |
| `name` | string | — | Project name, required when `create = true` |
| `description` | string | `""` | Project description |
| `quotas.compute` | object | `{}` | `cores`, `ram` (MiB), `instances` |
| `quotas.network` | map(number) | `{}` | Neutron quotas, for example `floatingip`, `network`, `port`, `router`, `security_group`, `security_group_rule` |
| `quotas.volume` | map(number) | `{}` | Cinder quotas, for example `volumes`, `gigabytes`, `snapshots` |

## `role_assignments`

Only with `project.create = true`. Map key: a free name for the assignment.

| Attribute | Type | Description |
|---|---|---|
| `kind` | string | `"user"` or `"group"` |
| `name` | string | Name of the existing user or group |
| `role` | string | Role name, for example `member` or `reader` |

## `existing`

Objects created by another stack, another team or the console. Each one is given **by exactly one of `id` or `name`**:

- with `id`, nothing is looked up: the ID may come from another module in the same configuration, even if that object is created in the same apply;
- with `name`, a data source resolves the object at plan time: it must already exist and be visible from the project.

| Attribute | Type | Description |
|---|---|---|
| `networks.<key>.id` / `.name` | string | Network to adopt |
| `networks.<key>.subnets.<key>.id` / `.name` | string | Subnets of that network that the model references (router gateways, ports) |
| `security_groups.<key>.id` / `.name` | string | Security group to adopt, typically from a shared catalog |
| `dns_zones.<key>.id` / `.name` | string | Zone owned by the project or shared with it |

> [!IMPORTANT]
> A DNS zone is usable only if the project **owns** it or if it is **shared** with the project. Zones should be created *for* a project or shared with it by the administrator; transferring a zone after creation hides it from the stack that created it.

## `networks`

Map key: network name (unless `name` is set).

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | string | key | OpenStack name |
| `mtu` | number | cloud default | MTU of the network |
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
| `dns_nameservers` | list(string) | `[]` | |
| `allocation_pools` | list({start, end}) | whole range | Addresses DHCP may allocate |
| `host_routes` | list({destination, nexthop}) | `[]` | Static routes pushed by DHCP |

**`routers.<key>`** — one router connects one subnet of this network to one external network. Several routers per network let each one reach a different network plane.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `external_network` | string | required | Key in `existing.networks` |
| `external_subnet` | string | any | Key of the external subnet for the gateway |
| `external_ip` | string | allocated | Fixed gateway address on the external network |
| `internal_subnet` | string | required | Key of the subnet of this network |
| `internal_ip` | string | allocated | Fixed router address on the internal subnet |
| `advertise_routes` | list(string) | `[]` | Destinations pushed to the internal subnet as host routes via this router |
| `admin_state_up` | bool | `true` | |
| `availability_zone_hints` | list(string) | `[]` | |

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

## `management_port`

An optional convention: every instance with `management_port = true` gets an extra port on a dedicated management network, with its own security groups.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `network` | string | required | Key in `networks` or `existing.networks` |
| `subnet` | string | any | Subnet key |
| `security_groups` | list(string) | required | Applied to every management port |
| `egress_security_groups` | list(string) | `[]` | Added when the instance sets `management_egress = true` |

## `instances`

Map key: instance name.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `az` | string | required | Availability zone |
| `flavor` / `flavor_id` | string | — | **Exactly one of**: flavor name or ID |
| `image` / `image_id` | string | — | Image name or ID; required unless `boot.source = "existing"` |
| `boot` | object | `{ source = "image" }` | See below |
| `management_port` | bool | `false` | Add a port on the `management_port` network |
| `management_egress` | bool | `false` | Also apply `management_port.egress_security_groups` |
| `ports` | map | required | See below |
| `volumes` | map | `{}` | See below |
| `user_data` | string | `null` | Cloud-init data, for example from `modules/cloudinit` |
| `labels` | list(string) | `[]` | Free labels, exposed in outputs and metadata for the layers above |
| `metadata` | map(string) | `{}` | Additional instance metadata |

**`boot`** — how the root disk is provided, selected by `source`:

| `source` | Attributes | Behaviour |
|---|---|---|
| `"image"` | — | Ephemeral root disk from the image |
| `"volume"` | `size`, `volume_type` | Root volume created from the image |
| `"existing"` | exactly one of `id`, `name` | Boot from an existing volume, for example to rebuild an instance on its surviving disk |

**`ports.<key>`** — the first port in key order is the primary interface.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `network` / `subnet` | string | required | Keys in `networks` or `existing.networks` |
| `fixed_ip` | string | allocated | Fixed address |
| `security_groups` | list(string) | `[]` | Keys of local or existing security groups |
| `floating_ip.pool` | string | — | External network providing the floating IP |
| `floating_ip.subnet` | string | any | Subnet of that network |
| `floating_ip.dns` | list({name, zone}) | `[]` | A records on the floating IP; `zone` is a key in `dns.zones` or `existing.dns_zones` |
| `dns` | list({name, zone}) | `[]` | A records on the fixed IP |

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
| `topology` | string | `"SINGLE"` | `"SINGLE"` or `"ACTIVE_STANDBY"` (amphora provider) |
| `flavor` | string | cloud default | Octavia flavor |
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

The composite exposes outputs keyed like the input, with a fixed shape (absent values are `null`). Their provider-neutral contract will be specified in a dedicated ADR; the current draft is:

| Output | Content |
|---|---|
| `instances` | `<name> => { id, az, labels, ports = { <port> => { ip, floating_ip, fqdn } } }` |
| `networks` | `<name> => { id, subnets = { <subnet> => { id, cidr } } }` |
| `security_groups` | `<name> => { id }` |
| `load_balancers` | `<name> => { id, vip, floating_ip }` |
| `dns_zones` | `<name> => { id, name }` |

## Building blocks

The building blocks take **IDs** instead of keys: wiring them together is the caller's code (see [`examples/building-blocks`](../examples/building-blocks)). Their interfaces mirror the matching slice of the model:

| Module | Main inputs | Main outputs |
|---|---|---|
| [`modules/network`](../modules/network) ✅ | `name`, `project_id`, `mtu`, `subnets` (as above), `routers` with `external_network_id`, `external_subnet_id`, `external_ip`, `internal_subnet`, `internal_ip`, `advertise_routes` | `id`, `name`, `subnets`, `routers` |
| [`modules/security-group`](../modules/security-group) ✅ | `name`, `description`, `project_id`, `delete_default_rules`, `rules` with `remote_group_id` (an ID, or `"self"`) instead of `remote_group` | `id`, `name`, `rule_ids` |
| [`modules/instance`](../modules/instance) ✅ | `name`, `project_id`, `az`, `flavor` / `flavor_id`, `image` / `image_id`, `boot`, `ports` with `network_id`, `subnet_id`, `fixed_ip`, `security_group_ids`, `port_security_enabled`, `allowed_address_pairs`, `floating_ip` (`pool`, `subnet_id`, `dns`) and `dns` (entries `{ name, zone_id, zone_name, ttl }`); `volumes`; `user_data`; `key_pair`; `server_group_id`; `labels`; `metadata`; `default_ttl` | `id`, `name`, `az`, `labels`, `ports`, `volumes` |
| `modules/loadbalancer` | `name`, `vip` with `subnet_id`, `topology`, `floating_ip`, `listeners` with members as `{ address, subnet_id }` | `id`, `vip`, `floating_ip` |
| `modules/dns` | `zones`, `records` with `zone_id` | `zones` |
| [`modules/cloudinit`](../modules/cloudinit) ✅ | `hostname`, `fqdn`, `timezone`, `users`, `packages`, `package_update`, `package_upgrade`, `disks`, `bind_mounts`, `write_files`, `runcmd`, `extra_config` | `rendered`, `config` |

✅ = implemented. Exact inputs are documented in each module's README.
