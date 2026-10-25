# ADR-0001: Module design

- **Status:** Proposed
- **Date:** 2026-10-21
- **Deciders:** Gregory Gabrielian

An *Architecture Decision Record* (ADR) captures one design decision, its context and its consequences. This ADR is revised in place until the first release; afterwards, changes go through new ADRs.

## Context

This repository started as an internal module that described a complete OpenStack tenant (networks, routers, security groups, instances, volumes, floating IPs, load balancers, DNS) in a single declarative model, and could adopt objects created elsewhere. Its history is kept.

That module served as an **inventory of features**, not as a compatibility target. It had five problems that prevented reuse:

1. **A single `plan` was impossible.** Some `for_each` keys depended on IDs known only after apply, which forced `-target` on every new instance.
2. **It mixed two roles**: cloud administration (flavors, images, aggregates, users, several projects at once) and tenant management (one project and its resources).
3. **Secrets went into the code** (user passwords, unused authentication variables).
4. **Default values described one specific site**, and conventions were hard-coded (port naming, security group names).
5. **Non-idempotent or surprising behaviours**: `mkfs` and `fstab` edits in cloud-init, `user_data` changes recreating every instance, security group rules indexed by position, roles forced to `admin`, DNS records silently written into every zone.

**Audience.** Reusable OpenStack Terraform material today consists of provider tutorials, examples published by public clouds and per-resource module collections; no maintained module describes a whole tenant with adoption of existing objects (GCP's project factory has no OpenStack equivalent). The primary audience is therefore **teams consuming OpenStack clouds without admin rights**, notably the European public and sovereign OpenStack clouds. Operators of private clouds, who usually already have their own tooling, are a secondary audience served by `cloud-baseline`.

Three guidelines from the Terraform ecosystem frame the decision:

- Split modules along **encapsulation, privileges and volatility** (HashiCorp, *Module creation – recommended pattern*).
- Prefer **dependency inversion**: a module receives the objects it depends on as inputs rather than looking them up (HashiCorp, *Module composition*).
- A declarative, data-driven description of many resources works best as a **composition layer over small modules** (the *factory* pattern of Google's Cloud Foundation Fabric, the project and account factories of the major clouds), not as a monolith.

## Options considered

1. **A single module for everything.** Simple to call, but mixes admin and project privileges, long-lived and short-lived resources, and grows an interface that is hard to document and to evolve.
2. **Only small modules per concern**, composed by the caller. Reusable and well understood, but the tenant is no longer described in one model: cross-references (ports to networks, members to instances) move into every caller's glue code.
3. **Small public building blocks, a thin composite tenant module on top, and a separate admin-level factory** (chosen). Callers who want one model use the composite; callers who need a different split use the building blocks directly. The same code serves both.

## Decision

### D1. Three layers, one repository

| Layer | Path | Credentials | Purpose |
|---|---|---|---|
| **Building blocks** | `modules/network`, `modules/security-group`, `modules/instance`, `modules/loadbalancer`, `modules/dns` | project-scoped | One concern each, small typed interface, usable on their own |
| **Tenant composite** | repository root | project-scoped | One declarative model for a tenant; resolves references by key and calls the building blocks |
| **Cloud baseline** | `modules/cloud-baseline` | cloud `admin` | Projects, quotas, users, groups, role assignments, aggregates, flavors, images, provider and shared networks, shared security group catalog, DNS zones |

- Building blocks are part of the public interface, documented and versioned like the composite.
- **The composite never creates its project.** Nova creates instances only in the project of the token (`openstack_compute_instance_v2` has no project argument), so a composite creating a project with admin credentials would put ports in the new project and instances in the admin project. Projects, quotas and role assignments belong to `cloud-baseline`; the tenant layers run in an existing project.
- **Release order follows the audience:** `v0.1.0` delivers the tenant layers (building blocks and composite); `cloud-baseline` follows in `v0.2.0`.
- **Portability across OpenStack clouds:** clouds differ in available services and policies. Octavia and Designate are optional: the composite works without them, and nothing assumes a specific deployment tool or vendor.
- Plain module calls cover volatility: a long-lived network layer and a short-lived compute layer can each have their own state, with the second receiving the first's outputs through `existing`.

### D2. Adoption by injection

Objects owned by another stack are passed **as values**, never only looked up inside the module:

```hcl
existing = {
  networks        = { transit = { id = module.baseline.networks["transit"].id, subnets = { site-a = { id = "..." } } } }
  security_groups = { ssh = { name = "baseline-ssh" } }        # a name is accepted too
  dns_zones       = { public = { id = "..." } }
}
```

- Every adopted network and security group accepts `id` **or** `name`. With `id`, the object may be created in the same apply (by `cloud-baseline` or another module in the same root) and still be adopted without a second plan. With `name`, a data source resolves it at plan time; the object must already exist.
- Adopted DNS zones always give their `name`, which builds record names and keys; their `id` is optional and avoids the lookup.
- Floating IP pools are keys of `existing.networks`, like every other reference; the composite resolves the network name Neutron expects.
- Flavors and images follow the same rule (`flavor = "m1.small"` or `flavor_id = "..."`).
- Volumes holding data are adopted with `existing = { id | name }` on the volume.

### D3. Tenant input model

One object, with maps keyed by name everywhere. Fields marked `?` are optional. HCL has no union types, so alternatives use a discriminator field (`source`, `kind`) checked by `validation` blocks.

```hcl
tenant = {
  # Resources are created in the project of the provider's credentials.

  existing? = {                                              # see D2
    networks        = { transit = { id? | name?, subnets = { site-a = { id? | name? } } } }
    security_groups = { ssh = { id? | name? } }
    dns_zones       = { public = { id?, name } }               # name always: it builds record names
  }

  networks? = {
    private = {
      name?, mtu?, admin_state_up? = true, availability_zone_hints? = []
      subnets = {
        main = {
          cidr, ip_version? = 4, gateway_ip?, enable_dhcp? = true
          dns_nameservers? = [], allocation_pools? = [{ start, end }]
          host_routes? = [{ destination, nexthop }]
        }
      }
      routers? = {
        to-transit = {
          external_network = "transit"                       # key in existing.networks
          external_subnet? = "site-a", external_ip?
          internal_subnet  = "main", internal_ip?            # fixed router IP on the tenant subnet
          advertise_routes? = ["10.10.0.0/22"]               # pushed by DHCP as host routes via this router
          admin_state_up? = true, availability_zone_hints? = []
        }
      }
    }
  }

  security_groups? = {
    web = {
      description?
      rules = { https-in = { direction = "ingress", ethertype? = "IPv4", protocol? = "tcp",
                             port_min? = 443, port_max? = 443, remote_ip_prefix?, remote_group? } }
    }
  }

  server_groups? = { web = { policy? = "anti-affinity", max_server_per_host? } }  # spread replicas over hosts

  instances? = {
    web-1 = {
      flavor? | flavor_id?, az, image? | image_id?
      boot? = { source = "image" }                           # or { source = "volume", size, volume_type? }
                                                             # or { source = "existing", id? | name? }
      server_group? = "web"
      ports = {
        private = {
          network = "private", subnet = "main", fixed_ip?
          security_groups = ["web", "ssh"]                   # local or existing keys
          floating_ip? = { pool = "public", subnet?, dns? = [{ name = "www", zone = "public" }] }
          dns? = [{ name = "www", zone = "internal" }]       # A record on the port IP
        }
      }
      volumes? = { data = { size = 20, az?, volume_type? } } # or { existing = { id? | name? } }
      user_data? = module.cloudinit["web-1"].rendered
      labels? = ["edge"]                                     # exposed in outputs and metadata
      metadata? = {}
    }
  }

  load_balancers? = {
    edge = {
      vip = { network = "private", subnet = "main", ip? }    # local or existing network
      flavor_id?, availability_zone?, security_groups? = []   # flavor_id: Octavia flavor (topology)
      floating_ip? = { pool = "public", subnet?, dns? = [{ name = "", zone = "public" }] }
      listeners = {
        https = {
          protocol = "TCP", port = 443, allowed_cidrs? = [], timeouts? = {}
          pool = {
            protocol = "PROXY", method = "ROUND_ROBIN"
            members = ["web-1.private"], member_port?        # instance.port
            monitor? = { type = "TCP", delay = 5, timeout = 3, max_retries = 3, url_path?, expected_codes? }
          }
        }
      }
    }
  }

  dns? = {
    zones?   = { app = { name = "app.example.org.", email, ttl?, description? } }
    records? = { mx = { zone = "public", name = "", type = "MX", records = ["10 mail.example.org."], ttl? } }
  }

  defaults? = { ttl = 3000 }
}
```

Each building block takes the matching slice of this model (for example, `modules/instance` takes one instance plus the resolved IDs of its networks and security groups).

### D4. `cloud-baseline` input model

```hcl
baseline = {
  projects = {
    demo = {
      description?, enabled? = true, tags? = []
      quotas? = {
        compute? = { cores, ram, instances }
        network? = { floatingip, network, subnet, port, router, security_group, security_group_rule, rbac_policy }
        volume?  = { volumes, snapshots, gigabytes, per_volume_gigabytes, backups, backup_gigabytes }
      }
    }
  }

  users? = {
    alice = {
      email?, enabled? = true, default_project?
      password? = { mode = "generate" }                      # "generate" | "input" | "none" (see D6)
    }
  }
  groups?           = { ops = { description?, members? = ["alice"] } }
  role_assignments? = { alice-demo = { kind = "user", name = "alice", project = "demo", role = "member" } }

  aggregates? = { site-a = { zone = "site-a", hosts = ["..."], metadata? = {} } }
  flavors?    = { m1-small = { vcpus = 2, ram = 4096, disk = 16, ephemeral?, is_public? = true, extra_specs? = {} } }
  images?     = { ubuntu-24-04 = { source_url, disk_format = "qcow2", container_format = "bare",
                                   min_disk?, visibility? = "public", properties? = {} } }

  networks? = {                                              # provider or shared internal networks
    transit = {
      external? = false, shared? = false, share_with? = []  # explicit RBAC targets
      physnet?, type? = "flat", segmentation_id?, mtu?, availability_zone_hints? = []
      subnets = { site-a = { cidr, gateway_ip?, enable_dhcp?, dns_nameservers?, allocation_pools?, host_routes? } }
    }
  }

  security_groups? = {                                       # shared catalog
    baseline-ssh = { description?, rules = { ... }, share_with? = ["*"] }  # sharing with all projects is explicit
  }

  dns_zones? = {
    demo     = { name = "demo.example.org.", email, ttl?, project = "demo" }               # owned by a tenant
    services = { name = "svc.example.org.", email, ttl?, share_with = ["demo", "other"] }   # kept by admin, shared
  }
}
```

DNS zones are never transferred between projects after creation. A zone transfer changes the owner behind the state's back: the creating stack can no longer read the zone and fails or tries to recreate it. Instead:

- **A zone dedicated to a tenant** is created **for** that project (`project`): the provider sends `X-Auth-Sudo-Tenant-ID`, so the baseline stack keeps reading the zone while the tenant owns it and manages its records. The user running the baseline needs a role in the target project.
- **A zone used by several tenants** stays owned by the administrator and is shared with each target project (`share_with`, Designate zone sharing, provider >= 3.2). Each tenant writes its own records.
- `project` and `share_with` are mutually exclusive (validation).

Outputs expose the IDs of every created object, keyed like the input, so that tenants can adopt them by injection (D2).

**Adoption in `cloud-baseline`** (added 2026-10-25, for v0.2). An administrator almost never starts from an empty cloud. The baseline therefore takes the same `existing` section as the tenant, by ID or by name, for the objects it references without owning them:

```hcl
baseline = {
  existing? = {
    projects = { legacy = { id? | name? } }   # receive quotas, shares, zones, roles
    users    = { alice  = { id? | name? } }   # from LDAP or federation: receive roles, never created
    groups   = { ops    = { id? | name? } }
    networks = { ext    = { id? | name? } }   # created by the deployment tool: receive subnets, shares
    images   = { ubuntu = { id? | name? } }   # built by an image pipeline: shared with projects
  }
  # role_assignments, share_with, dns_zones.*.project and images.*.share_with accept keys of
  # created or adopted objects alike.
}
```

Two needs are kept apart:

- **Adoption**: referencing an object that stays managed elsewhere (the `existing` section above).
- **Takeover**: bringing an object created by hand under the baseline's management. This is done with `import` blocks and documented in a guide ("taking over an existing cloud"), not in the model.

Image sharing also needs the project-side acceptance (`openstack_images_image_access_accept_v2`) to be visible to projects with the `member` role; integration tests showed that a `shared` image without accepted members is invisible to them.

### D5. Stable keys: one plan, no `-target`

- `for_each` collections and keys come **only from the input**, never from attributes computed at apply time. Values passed to resources may be unknown at plan time; keys may not.
- IP addresses are read from the port resource itself, never by filtering other resources on `device_id`.
- Outputs have a **fixed shape**: no conditional `merge`, absent fields are `null`.
- **Acceptance criterion:** on an empty project, `plan` succeeds in one pass, including when `cloud-baseline` and the tenant are applied from the same root, and the plan following `apply` is empty, with both OpenTofu and Terraform.

### D6. Secrets: what the modules do, and only that

1. **No unnecessary secret.** The tenant layers create none; `cloud-baseline` creates user passwords only (and optional application credentials).
2. **Three password modes:** `generate` (default: `random_password`, delivered once through a `sensitive` output; Keystone never returns passwords, so a later change by the user causes no drift; rotation with `-replace`), `input` (provided by the caller in a separate `sensitive` map), `none` (federation, LDAP).
3. **Every secret input and output is `sensitive`.** `sensitive` hides values from the CLI output, not from the state.
4. **No secret in `user_data`**: cloud-init data is readable by the whole project through the metadata service.
5. **Planned:** move to `ephemeral` variables and write-only attributes as soon as the OpenStack provider supports them; passwords will then leave the state.
6. **No `backend` block, no provider configuration, no dependency** on any secret store, storage or CI tool.

### D7. Operations are out of scope

The modules configure **no backend, no state encryption, no locking, no secret source and no execution pipeline** (CI, GitOps). These belong to the operator, in their root configuration. The modules behave the same with a manual `apply` or a full GitOps pipeline.

### D8. Least privilege really works

- Tenant layers need only a member role on their project. They never list or read projects: resources are created in the project of the provider's token.
- DNS records can only be written in zones owned by the project or shared with it. `cloud-baseline` creates tenant-owned zones (`project`) or shares administrator-owned zones (`share_with`); see D4. Zone transfers are not used.
- Quotas and role assignments are admin operations, available only in `cloud-baseline`.

### D9. Predictable behaviour

- **`lifecycle` cannot be configured by a variable**, so behaviours are fixed and documented:
  - `user_data` changes are ignored on existing instances (`ignore_changes = [user_data]`). To apply a new cloud-init, replace the instance explicitly (`-replace`).
  - The modules set **no `prevent_destroy`**. Data that must survive belongs in volumes created outside the module (by the caller, who can protect them with their own `lifecycle`) and adopted with `existing`.
- `user_data` is an input, rendered by `modules/cloudinit`. Data volumes are attached after boot, so cloud-init's `fs_setup` and `mounts` would run before the device exists: each disk is handled by an idempotent systemd unit that waits for the device, formats it only when it holds no file system, and mounts it by label at every boot.
- Security group rules keyed by name.
- Octavia: the topology (single or active/standby) is not a load balancer attribute but a property of the Octavia **flavor** chosen by the cloud administrator, so the model exposes `flavor_id`. Examples use TCP/HTTP health monitors; `PING` remains available.
- Declared roles are applied as declared.

### D10. No site-specific defaults

- No topological default values. `validation` blocks on CIDRs, names, protocols, methods, discriminator fields and cross-references (a router's `external_network` must exist in `existing.networks`).
- Conventions become options: shared security group catalog, default TTL. A site convention such as a dedicated management network is not an option of the model: it is one more port, added by the caller (an earlier draft had a `management_port` option, removed before v0.1.0 as too specific).

### D11. Provider-neutral output contract

The composite exposes outputs that upper layers (cluster bootstrap, configuration management, inventories) consume without knowing the cloud: instances with labels, ports, addresses and names; networks; load balancer endpoints; DNS names. The contract contains no OpenStack-specific notion and is specified in a separate ADR, so that equivalent projects for other clouds can implement it and be swapped in a composite deployment.

### D12. Compatibility

- **OpenTofu ≥ 1.6 and Terraform ≥ 1.6**, on equal footing. CI validates both tools at their lowest supported and latest versions. Test tooling may require newer versions; this does not constrain users.
- Provider `terraform-provider-openstack/openstack ~> 3.2` (zone sharing).

### D13. Repository layout

```
terraform-openstack-tenant/
├── main.tf, variables.tf, outputs.tf, versions.tf   # tenant composite
├── modules/
│   ├── network/  security-group/  instance/  loadbalancer/  dns/   # public building blocks
│   ├── cloud-baseline/                                            # admin-level factory
│   └── cloudinit/
├── examples/{lab-single-stack, baseline-plus-tenant, adopt-existing, layered-network-compute, public-edge, building-blocks}/
├── tests/
└── docs/
```

## Consequences

- No backward compatibility with the original module: input names and shapes are free. The code is rewritten in atomic commits on top of the original history.
- Two levels of public interface (composite and building blocks) must be documented, tested and versioned together.
- terraform-docs shows the composite as a single, deeply nested variable; a hand-written reference of the tenant model is required (`docs/tenant-model.md`).
- Generated passwords stay in the state until the provider supports write-only attributes; protecting the state is the operator's responsibility (D7).
- Applying a new cloud-init to a running instance is always an explicit replacement.

## Test strategy

1. **Without a cloud, on every pull request:** `tofu test` and `terraform test` with mocked providers (key stability, validations, output shape, empty-project plan, baseline and tenant in the same root).
2. **`cloud-baseline` on a disposable DevStack:** it manages cloud-global objects (flavors, public images, aggregates, provider networks, users, RBAC) and must never be tested on a production cloud.
3. **Tenant layers on real clouds, at least two different ones** (a private cloud and a public OpenStack cloud), including one without Octavia or Designate: a dedicated project with project-scoped application credentials; scenario `apply` → empty `plan` → `destroy`. DNS cases: records in a tenant-owned zone and in a shared zone, lookup of a shared zone by name from the target project, behaviour when the owner deletes a shared zone that contains records of other projects.
