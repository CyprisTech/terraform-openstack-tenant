variable "hostname" {
  description = "Hostname of the instance."
  type        = string
}

variable "fqdn" {
  description = "Fully qualified domain name; null keeps the hostname only."
  type        = string
  default     = null
}

variable "timezone" {
  description = "Time zone, for example \"Etc/UTC\" or \"Europe/Paris\"."
  type        = string
  default     = "Etc/UTC"
}

variable "users" {
  description = <<-EOT
    Users to create, keyed by login.
    - ssh_authorized_keys: public keys allowed to log in.
    - sudo: grant passwordless sudo.
    - groups: supplementary groups.
    - shell: login shell.
    No passwords: cloud-init data is readable by the whole project through the metadata service.
  EOT
  type = map(object({
    ssh_authorized_keys = optional(list(string), [])
    sudo                = optional(bool, false)
    groups              = optional(list(string), [])
    shell               = optional(string, "/bin/bash")
  }))
  default = {}
}

variable "packages" {
  description = "Packages to install at first boot."
  type        = list(string)
  default     = []
}

variable "package_update" {
  description = "Refresh the package index at first boot."
  type        = bool
  default     = true
}

variable "package_upgrade" {
  description = "Upgrade installed packages at first boot."
  type        = bool
  default     = false
}

variable "disks" {
  description = <<-EOT
    Data disks to format (only if they have no file system yet) and mount, keyed by name.
    Volumes are usually attached after the instance has booted, so each disk is handled by a
    systemd service that waits for the device, runs at every boot and is idempotent.
    - device: block device, for example "/dev/vdb" or a stable "/dev/disk/by-id/virtio-<id>" path.
    - filesystem: "ext4" or "xfs".
    - mountpoint: where to mount it.
    - label: file system label used to mount it; defaults to the key (16 characters max for ext4, 12 for xfs).
    - options: mount options.
    - owner / group / mode: applied to the mountpoint after mounting; null leaves them unchanged.
    - wait_seconds: how long to wait for the device to appear.
  EOT
  type = map(object({
    device       = string
    filesystem   = optional(string, "ext4")
    mountpoint   = string
    label        = optional(string)
    options      = optional(string, "defaults,nofail")
    owner        = optional(string)
    group        = optional(string)
    mode         = optional(string)
    wait_seconds = optional(number, 600)
  }))
  default = {}

  validation {
    condition     = alltrue([for d in values(var.disks) : contains(["ext4", "xfs"], d.filesystem)])
    error_message = "disks.*.filesystem must be ext4 or xfs."
  }

  validation {
    condition     = alltrue([for k, d in var.disks : length(coalesce(d.label, k)) <= (d.filesystem == "xfs" ? 12 : 16)])
    error_message = "Disk labels are limited to 16 characters for ext4 and 12 for xfs; set label explicitly."
  }

  validation {
    condition     = alltrue([for d in values(var.disks) : startswith(d.mountpoint, "/") && startswith(d.device, "/dev/")])
    error_message = "disks.*.mountpoint must be absolute and disks.*.device must start with /dev/."
  }
}

variable "bind_mounts" {
  description = <<-EOT
    Directories of a data disk bind-mounted elsewhere, keyed by name, for example to keep
    /var/lib/docker on a data volume.
    - disk: key in disks.
    - path: directory relative to the disk's mountpoint (created if missing).
    - target: absolute path where it is mounted.
  EOT
  type = map(object({
    disk   = string
    path   = string
    target = string
  }))
  default = {}

  validation {
    condition     = alltrue([for b in values(var.bind_mounts) : startswith(b.target, "/") && !startswith(b.path, "/")])
    error_message = "bind_mounts.*.target must be absolute and bind_mounts.*.path relative to the disk."
  }
}

variable "write_files" {
  description = <<-EOT
    Files to write at first boot, keyed by absolute path.
    - content: file content.
    - owner: "user:group".
    - permissions: octal string, for example "0644".
    Never put secrets here: cloud-init data is readable by the whole project.
  EOT
  type = map(object({
    content     = string
    owner       = optional(string, "root:root")
    permissions = optional(string, "0644")
  }))
  default = {}
}

variable "runcmd" {
  description = "Commands run once at the end of the first boot."
  type        = list(string)
  default     = []
}

variable "extra_config" {
  description = "Additional top-level cloud-config keys, merged last (advanced use)."
  type        = any
  default     = {}
}
