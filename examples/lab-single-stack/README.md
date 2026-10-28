# Lab: a complete tenant in one stack

A network and its router, two security groups, and two instances, each with a data volume and a floating IP, bootstrapped by `modules/cloudinit` (user, packages, data disk formatted only when empty and mounted by label). Runs in an existing project with a member role.

## Run

```bash
export OS_CLOUD=mycloud
tofu init
tofu apply -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" -var admin_cidr=203.0.113.10/32
```

| Variable | Meaning |
|---|---|
| `ssh_public_key` | Key installed for the `ops` user |
| `admin_cidr` | Address allowed to reach the instances over SSH, as the cloud sees it ([source NAT](../../docs/pitfalls.md#source-addresses-behind-routers)) |

Output: `instances`. Check the data disk with `ssh ops@<floating IP> findmnt /srv/data`.
