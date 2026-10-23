# Module: cloudinit

Renders a cloud-config document for `user_data`: hostname, users, packages, files, commands, and **data disks that are formatted only when empty and mounted at every boot**. No provider is involved; the output is a string.

```hcl
module "cloudinit" {
  source = "github.com/CyprisTech/terraform-openstack-tenant//modules/cloudinit?ref=v0.1.0"

  hostname = "app-1"
  users    = { ops = { ssh_authorized_keys = [var.ssh_public_key], sudo = true } }
  packages = ["htop"]

  disks = {
    data = { device = "/dev/vdb", mountpoint = "/srv/data", owner = "ops" }
  }
  bind_mounts = {
    docker = { disk = "data", path = "docker", target = "/var/lib/docker" }
  }
}

module "app" {
  source    = "github.com/CyprisTech/terraform-openstack-tenant//modules/instance?ref=v0.1.0"
  # ...
  user_data = module.cloudinit.rendered
  volumes   = { data = { size = 50 } }
}
```

## How data disks are handled

Data volumes are usually attached **after** the instance has booted, so cloud-init's own `fs_setup` and `mounts` would run before the device exists. Instead, each disk gets a script and a systemd unit (`disk-<key>.service`), enabled at first boot and run at every boot:

1. wait for the device (up to `wait_seconds`);
2. **refuse** to touch a device that holds a partition table;
3. format it **only if it holds no file system** (checked with `blkid`), with a label;
4. mount it **by label**, so a device renamed after a reboot (`/dev/vdb` → `/dev/vdc`) is still mounted at the right place;
5. apply `owner`, `group` and `mode` to the mountpoint.

Bind mounts (`bind-<key>.service`) require their disk unit and start before `docker.service` and `containerd.service`, so that data directories are in place before applications.

Mounts are done by these units, not through `/etc/fstab`: a missing volume never blocks the boot.

> [!WARNING]
> cloud-init data is readable by the whole project through the metadata service. Never put passwords, keys or tokens in `write_files` or `runcmd`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname of the instance. | `string` | n/a | yes |
| <a name="input_bind_mounts"></a> [bind\_mounts](#input\_bind\_mounts) | Directories of a data disk bind-mounted elsewhere, keyed by name, for example to keep<br/>/var/lib/docker on a data volume.<br/>- disk: key in disks.<br/>- path: directory relative to the disk's mountpoint (created if missing).<br/>- target: absolute path where it is mounted. | <pre>map(object({<br/>    disk   = string<br/>    path   = string<br/>    target = string<br/>  }))</pre> | `{}` | no |
| <a name="input_disks"></a> [disks](#input\_disks) | Data disks to format (only if they have no file system yet) and mount, keyed by name.<br/>Volumes are usually attached after the instance has booted, so each disk is handled by a<br/>systemd service that waits for the device, runs at every boot and is idempotent.<br/>- device: block device, for example "/dev/vdb" or a stable "/dev/disk/by-id/virtio-<id>" path.<br/>- filesystem: "ext4" or "xfs".<br/>- mountpoint: where to mount it.<br/>- label: file system label used to mount it; defaults to the key (16 characters max for ext4, 12 for xfs).<br/>- options: mount options.<br/>- owner / group / mode: applied to the mountpoint after mounting; null leaves them unchanged.<br/>- wait\_seconds: how long to wait for the device to appear. | <pre>map(object({<br/>    device       = string<br/>    filesystem   = optional(string, "ext4")<br/>    mountpoint   = string<br/>    label        = optional(string)<br/>    options      = optional(string, "defaults,nofail")<br/>    owner        = optional(string)<br/>    group        = optional(string)<br/>    mode         = optional(string)<br/>    wait_seconds = optional(number, 600)<br/>  }))</pre> | `{}` | no |
| <a name="input_extra_config"></a> [extra\_config](#input\_extra\_config) | Additional top-level cloud-config keys, merged last (advanced use). | `any` | `{}` | no |
| <a name="input_fqdn"></a> [fqdn](#input\_fqdn) | Fully qualified domain name; null keeps the hostname only. | `string` | `null` | no |
| <a name="input_package_update"></a> [package\_update](#input\_package\_update) | Refresh the package index at first boot. | `bool` | `true` | no |
| <a name="input_package_upgrade"></a> [package\_upgrade](#input\_package\_upgrade) | Upgrade installed packages at first boot. | `bool` | `false` | no |
| <a name="input_packages"></a> [packages](#input\_packages) | Packages to install at first boot. | `list(string)` | `[]` | no |
| <a name="input_runcmd"></a> [runcmd](#input\_runcmd) | Commands run once at the end of the first boot. | `list(string)` | `[]` | no |
| <a name="input_timezone"></a> [timezone](#input\_timezone) | Time zone, for example "Etc/UTC" or "Europe/Paris". | `string` | `"Etc/UTC"` | no |
| <a name="input_users"></a> [users](#input\_users) | Users to create, keyed by login.<br/>- ssh\_authorized\_keys: public keys allowed to log in.<br/>- sudo: grant passwordless sudo.<br/>- groups: supplementary groups.<br/>- shell: login shell.<br/>No passwords: cloud-init data is readable by the whole project through the metadata service. | <pre>map(object({<br/>    ssh_authorized_keys = optional(list(string), [])<br/>    sudo                = optional(bool, false)<br/>    groups              = optional(list(string), [])<br/>    shell               = optional(string, "/bin/bash")<br/>  }))</pre> | `{}` | no |
| <a name="input_write_files"></a> [write\_files](#input\_write\_files) | Files to write at first boot, keyed by absolute path.<br/>- content: file content.<br/>- owner: "user:group".<br/>- permissions: octal string, for example "0644".<br/>Never put secrets here: cloud-init data is readable by the whole project. | <pre>map(object({<br/>    content     = string<br/>    owner       = optional(string, "root:root")<br/>    permissions = optional(string, "0644")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_config"></a> [config](#output\_config) | The cloud-config as an object, for inspection or further merging. |
| <a name="output_rendered"></a> [rendered](#output\_rendered) | Cloud-config document to pass as user\_data. |
<!-- END_TF_DOCS -->
