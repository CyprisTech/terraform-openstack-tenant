# Integration tests

These tests apply the composite on a **real OpenStack cloud**, check that the plan after `apply` is empty, then destroy everything. They complement the mocked tests in `tests/*.tftest.hcl`, which run in CI without a cloud.

> [!WARNING]
> These tests create real resources (instances, volumes, floating IPs, an Octavia load balancer, DNS records) and may cost money on a public cloud. Run them in a **dedicated, disposable project**, with credentials scoped to that project.

## Prerequisites

- OpenTofu (or Terraform with `TOOL=terraform`).
- A dedicated project and project-scoped credentials in `clouds.yaml`, for example an application credential with the `member` role (plus `load-balancer_member` if your Octavia policy requires it):
  ```yaml
  clouds:
    my-test-cloud:
      auth_type: v3applicationcredential
      auth:
        auth_url: https://keystone.example.org:5000/v3
        application_credential_id: "..."
        application_credential_secret: "..."
      region_name: RegionOne
  ```
- In that project: an external network usable as router gateway and floating IP pool, an image with cloud-init, two small flavors (one with a local disk, one without), a DNS zone owned by the project, a DNS zone shared with the project (stage 03), and a shared security group (stage 04).
- `env.tfvars`: copy [`env.tfvars.example`](env.tfvars.example) and adapt it. It is git-ignored. For several clouds, use one file per `clouds.yaml` entry, `env.<cloud>.tfvars`: `run.sh` picks it when `OS_CLOUD=<cloud>`, and keeps one workspace (state) per cloud.
- Optional features: leave `zone_name` and `shared_zone_name` unset on clouds without Designate, and `shared_security_group` unset when no shared group exists; `second_external_network` defaults to `external_network`.

## Running

```bash
cd tests/integration
export OS_CLOUD=my-test-cloud          # default: tf-module-test
./run.sh 01-network plan               # nothing is created
./run.sh 01-network full               # apply, check (empty plan), destroy
```

`run.sh` unsets every `OS_*` variable except `OS_CLOUD`, keeps the state locally in the stage directory, asks for confirmation before `apply` and `destroy` (set `AUTO_APPROVE=1` to skip) and writes a log to `.logs/` (git-ignored). With `full`, `destroy` runs even if the check fails.

## Stages

| Stage | Creates | Checks |
|---|---|---|
| `01-network` | network, subnet, router to the external network, security group | single plan; empty plan after apply; the router holds the subnet's gateway address |
| `02-instance` | + 1 instance booting from a new root volume, 1 data volume, cloud-init, 1 floating IP, 2 DNS records in the owned zone | empty plan after apply; data disk formatted and mounted (console log `disk-data:`); records created |
| `03-loadbalancer` | + 2 instances, Octavia load balancer (TCP 22, TCP monitor), floating IP on the VIP, DNS record in the **shared** zone, security group rule between local groups | empty plan after apply; members `ONLINE`; record in a shared zone |
| `04-complete` | 2 networks, 2 routers on one subnet with an advertised route, adopted shared security group, a second port on the other network, CNAME record | empty plan after apply; host route on the subnet; second port present |
| `05-extra-floating-ips` | 1 network, 2 routers to two external networks, 1 instance whose port has a primary floating IP and an extra floating IP on the second network, an A record on each | empty plan after apply; both floating IPs `ACTIVE` on the same fixed IP; outputs `floating_ip`, `floating_ips` and the port `id` |

Stages are independent: each one creates and destroys its own resources, under names starting with `it0N-`, so that leftovers are easy to identify.

## Cleaning up after a failed run

```bash
./run.sh <stage> destroy
```

If `destroy` itself fails, list leftovers with `openstack server list`, `openstack network list`, `openstack loadbalancer list` and `openstack recordset list <zone>`, filtering on the `it0N-` prefix.
