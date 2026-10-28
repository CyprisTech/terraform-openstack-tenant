# Operating the module

The modules deliberately contain **no operational choices**: no backend, no provider configuration, no secret store, no pipeline. This page lists what an operator has to decide and the options commonly used. None of them is required by the modules. Problems that come from the cloud itself are in [real-cloud pitfalls](pitfalls.md).

## Decision checklist

| Topic | Question to answer | Why it matters |
|---|---|---|
| State storage | Where is each state stored, and who can read it? | The state contains generated passwords and every attribute of every resource |
| State encryption | Is the state encrypted at rest, and is it encrypted before leaving the client? | Server-side encryption protects disks and backups; only client-side encryption protects against readers of the storage |
| Locking | How are concurrent runs on the same state prevented? | Two simultaneous applies can overwrite each other's state and orphan resources |
| Secret inputs | Where do passwords provided in `input` mode come from? | They must never be committed |
| Execution | Who runs `plan` and `apply`, from where, with which credentials? | Determines who needs admin or project credentials |
| State layout | How many states, and how are they separated? | Limits the impact of a leaked access key |

## State storage and locking

Both OpenTofu and Terraform support these backends:

| Backend | Locking | Notes |
|---|---|---|
| `s3` against any S3-compatible object store (Ceph RGW, OpenStack Swift with `s3api`, MinIO...) | `use_lockfile = true` (OpenTofu >= 1.10, Terraform >= 1.11) | Keeps state inside your own infrastructure; enable versioning and server-side encryption on the bucket |
| `http` (for example GitLab-managed state) | native | Access follows the permissions of the hosting project |
| `pg` (PostgreSQL) | native (advisory locks) | Convenient if a managed database already exists |
| `local` | file lock, single machine | Labs and examples only |
| Managed services (HCP Terraform, Spacelift, env0, Scalr...) | native | Encryption, access control and run history included |

The native `swift` backend no longer exists in Terraform (removed in 1.3) and was never part of OpenTofu.

## Protecting secrets in state

- Treat **every** state file as a secret: tenant states may also contain application passwords or API tokens passed by your own configuration.
- Grant read access to state only to the pipeline and to a small group of administrators, with one access key per state or per group of states.
- **OpenTofu** (>= 1.7) can encrypt the state on the client before storing it, for example with the built-in `pbkdf2` key provider and a passphrase held by your pipeline. **Terraform** has no client-side state encryption; rely on storage encryption and access control.
- `sensitive = true` hides values in CLI output only.

## Providing secrets

Passwords in `input` mode are ordinary `sensitive` variables. Common sources: CI/CD protected variables exported as `TF_VAR_*`, files encrypted with SOPS, or a secret manager (Vault, OpenBao, Barbican) read in your root configuration. The modules work with any of them and depend on none.

## Running with GitOps

A typical pull-request workflow, independent of the tool:

1. Code and non-secret values live in Git; every change goes through a pull request.
2. CI runs `plan` on the pull request and publishes the result for review.
3. After merge, CI runs `apply`, automatically or after a manual approval.
4. A scheduled `plan` detects drift (changes made outside Git).
5. Only the pipeline holds cloud credentials, state access and the state encryption key.

Common implementations: GitLab CI or GitHub Actions jobs, Atlantis, Flux with tofu-controller, managed services listed above.

## Credentials

- The baseline stack needs a cloud `admin` role. Keep it separate from tenant pipelines.
- Tenant stacks need only a member role on their project; [application credentials](https://docs.openstack.org/keystone/latest/user/application_credentials.html) scoped to the project are a good fit for pipelines.
- Configure the provider with `clouds.yaml` and `OS_CLOUD`, or with `OS_*` environment variables. Never hard-code credentials in configuration files.

## Recovering a load balancer in `ERROR`

Octavia can leave a load balancer in `ERROR` when an amphora fails to build. It then removes the VIP port, and every later plan fails while reading the load balancer:

```text
Error getting port security groups for openstack_lb_loadbalancer_v2: ... PortNotFound
```

The failed load balancer is already marked as tainted in the state. Rebuild it without refreshing it:

```bash
# 1. Refresh everything else (state only, no change to the cloud).
tofu apply -refresh-only -target='module.tenant.module.instance'

# 2. Replace the load balancer; listeners, pools, members and the floating IP association follow.
tofu plan  -refresh=false -replace='module.tenant.module.loadbalancer["edge"].openstack_lb_loadbalancer_v2.this' -out=lb.tfplan
tofu apply lb.tfplan

# 3. Back to normal: the next plan refreshes everything and must be empty.
tofu plan -detailed-exitcode
```

Step 1 matters: without it, `-refresh=false` compares the configuration with a state that was never read back, and the plan shows in-place changes on instances (for example `scheduler_hints`) that do not exist on the cloud.

## Recovering a DNS record created after a timeout

When Designate is slow, `apply` can time out on a record that Designate creates later; the next `apply` then fails with `Duplicate RecordSet`. Import the record instead of deleting it: see [real-cloud pitfalls](pitfalls.md#dns).
