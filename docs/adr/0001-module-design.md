# ADR-0001: Module design

- **Status:** Accepted
- **Date:** 2026-10-21
- **Deciders:** Gregory Gabrielian

An *Architecture Decision Record* (ADR) captures one design decision, its context and its consequences.

## Context

This repository started as an internal module that described a complete OpenStack tenant (networks, routers, security groups, instances, volumes, floating IPs, load balancers, DNS) in a single declarative model, and could adopt objects created elsewhere. Its history is kept.

That module served as an **inventory of features**, not as a compatibility target. It had five problems that prevented reuse:

1. **A single `plan` was impossible.** Some `for_each` keys depended on IDs known only after apply, which forced `-target` on every new instance.
2. **It mixed two roles**: cloud administration (flavors, images, aggregates, users, several projects at once) and tenant management (one project and its resources).
3. **Secrets went into the code** (user passwords, unused authentication variables).
4. **Default values described one specific site**, and conventions were hard-coded (port naming, security group names).
5. **Non-idempotent or surprising behaviours**: `mkfs` and `fstab` edits in cloud-init, `user_data` changes recreating every instance, security group rules indexed by position, roles forced to `admin`, DNS records silently written into every zone.

## Decision

### D1. Two modules, two privilege levels, one repository

- **`modules/cloud-baseline`** manages what requires the cloud `admin` role: projects, quotas, users, groups, role assignments, aggregates, flavors, images, provider and shared networks, a shared security group catalog, DNS zones.
- **The root module (the tenant)** manages what lives *inside* one project: networks, routers, security groups, instances, volumes, ports, floating IPs, load balancers, DNS records. It runs with **project-scoped** credentials.
- For labs, `project.create = true` lets the tenant module create its own project.

### D2. Tenant input model

One object, with maps keyed by name everywhere. Fields marked `?` are optional.

```hcl
tenant = {
  project = { name = "demo", create? = false, description?, quotas? = {...} }  # quotas only when create
  role_assignments? = { ops = { group? | user?, role = "member" } }            # only when create

  # Adoption: objects created elsewhere (cloud-baseline, another stack, the console)
  existing? = {
    networks        = { transit = { name = "transit", subnets = { site-a = "transit-site-a" } } }
    security_groups = { ssh = { name = "baseline-ssh" }, legacy = { id = "..." } }
    dns_zones       = { public = "demo.example.org." }
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
                             port_min? = 443, port_max? = 443, remote_ip_prefix? | remote_group? } }
    }
  }

  management_port? = {                                       # optional dedicated management network
    network = "management", subnet?, security_groups = ["ssh", "dhcp"],
    egress_security_groups? = ["ssh-egress"]
  }

  instances? = {
    web-1 = {
      flavor, az, image?                                     # flavors and images resolved by name
      boot? = { source = "image" } | { source = "volume", size, volume_type?, existing? = false, name? }
      management_port? = true, management_egress? = false
      ports = {
        private = {
          network = "private", subnet = "main", fixed_ip?
          security_groups = ["web", "ssh"]                   # local or existing keys
          floating_ip? = { pool = "public", subnet?, dns? = [{ name = "www", zone = "public" }] }
          dns? = [{ name = "www", zone = "internal" }]       # A record on the port IP
        }
      }
      volumes? = { data = { size = 20, az?, volume_type?, existing? = false, name? } }
      user_data? = module.cloudinit["web-1"].rendered
      labels? = ["edge"]                                     # exposed in outputs and metadata
      metadata? = {}
    }
  }

  load_balancers? = {
    edge = {
      vip = { network = "private", subnet = "main", ip? }    # local or existing network
      topology? = "SINGLE", flavor?
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

  defaults? = { ttl = 3000, ignore_user_data_changes = true }
}
```

### D3. `cloud-baseline` input model

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
      password? = { mode = "generate" }                      # "generate" | "input" | "none" (see D5)
    }
  }
  groups?           = { ops = { description?, members? = ["alice"] } }
  role_assignments? = { alice-demo = { user? | group?, project, role = "member" } }

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

  dns_zones? = { svc = { name = "svc.example.org.", email, ttl?, project? } }
}
```

### D4. Stable keys: one plan, no `-target`

- Resources are keyed by **names from the input** (`"web-1.private"`, `"to-transit"`), **never by computed attributes**.
- IP addresses are read from the port resource itself, never by filtering other resources on `device_id`.
- Adopted objects (`existing`, `boot.existing`, `volumes.*.existing`) are data sources keyed like the resource they replace; each reference knows at plan time whether it points to an adopted or a created object.
- Outputs have a **fixed shape**: no conditional `merge`, absent fields are `null`.
- **Acceptance criterion:** on an empty project, `plan` succeeds in one pass, and the plan following `apply` is empty, with both OpenTofu and Terraform.

### D5. Secrets: what the module does, and only that

1. **No unnecessary secret.** The tenant module creates none; `cloud-baseline` creates user passwords only (and optional application credentials).
2. **Three password modes:** `generate` (default: `random_password`, delivered once through a `sensitive` output, then `ignore_changes` so users can change it in Keystone without drift; rotation with `-replace`), `input` (provided by the caller in a separate `sensitive` map), `none` (federation, LDAP).
3. **Every secret input and output is `sensitive`.** `sensitive` hides values from the CLI output, not from the state.
4. **No secret in `user_data`**: cloud-init data is readable by the whole project through the metadata service.
5. **Planned:** move to `ephemeral` variables and write-only attributes as soon as the OpenStack provider supports them; passwords will then leave the state.
6. **No `backend` block, no provider configuration, no dependency** on any secret store, storage or CI tool.

### D6. Operations are out of scope

The module configures **no backend, no state encryption, no locking, no secret source and no execution pipeline** (CI, GitOps). These belong to the operator, in their root configuration. The module behaves the same with a manual `apply` or a full GitOps pipeline.

### D7. No site-specific defaults

- No topological default values. `validation` blocks on CIDRs, names, protocols, methods and cross-references (a router's `external_network` must exist in `existing.networks`).
- Conventions become options: `management_port`, shared security group catalog, default TTL.

### D8. Predictable behaviour

- `user_data` is an input, rendered by the `cloudinit-ubuntu` module of this repository (idempotent disk setup with `fs_setup` and `mounts`). **`ignore_user_data_changes = true` by default.**
- `prevent_destroy` on boot and data volumes.
- Security group rules keyed by name.
- Octavia: `topology` is exposed; examples use TCP/HTTP health monitors; `PING` remains available.
- Declared roles are applied as declared.

### D9. Compatibility

- **OpenTofu ≥ 1.6 and Terraform ≥ 1.6**, on equal footing. CI validates both tools at their lowest supported and latest versions. Test tooling may require newer versions; this does not constrain users.
- Provider `terraform-provider-openstack/openstack ~> 3.x`.

### D10. Repository layout

```
terraform-openstack-tenant/
├── main.tf, variables.tf, outputs.tf, versions.tf   # tenant module (root)
├── modules/
│   ├── cloud-baseline/
│   ├── network/  security-group/  instance/  loadbalancer/  dns/
│   └── cloudinit-ubuntu/
├── examples/{lab-single-stack, baseline-plus-tenant, adopt-existing, public-edge}/
├── tests/
└── docs/adr/
```

## Consequences

- No backward compatibility with the original module: input names and shapes are free. The code is rewritten in atomic commits on top of the original history.
- Two state files are expected in a typical deployment (baseline, then one per tenant), with different privilege levels.
- The state still contains generated passwords until the provider supports write-only attributes; protecting it is the operator's responsibility (D6).

## Test strategy

1. **Without a cloud, on every pull request:** `tofu test` and `terraform test` with mocked providers (key stability, validations, output shape, empty-project plan).
2. **`cloud-baseline` on a disposable DevStack:** it manages cloud-global objects (flavors, public images, aggregates, provider networks, users, RBAC) and must never be tested on a production cloud.
3. **Tenant module on a real cloud:** a dedicated project with project-scoped application credentials; scenario `apply` → empty `plan` → `destroy`.
