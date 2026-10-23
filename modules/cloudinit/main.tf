locals {
  # Mount options used by the disk scripts. "nofail" is an fstab option that
  # mount(8) ignores; it is removed to keep the command line clean.
  disks = {
    for k, d in var.disks : k => merge(d, {
      label   = coalesce(d.label, k)
      options = join(",", [for o in split(",", d.options) : o if o != "nofail" && o != ""])
    })
  }

  # Services that bind mounts must start before, so that applications see
  # their data directories.
  bind_units = [for k in sort(keys(var.bind_mounts)) : "bind-${k}.service"]

  disk_files = flatten([
    for k, d in local.disks : [
      {
        path        = "/usr/local/sbin/disk-setup-${k}"
        permissions = "0755"
        owner       = "root:root"
        content = templatefile("${path.module}/templates/disk-setup.sh.tftpl", {
          key          = k
          device       = d.device
          label        = d.label
          mountpoint   = d.mountpoint
          filesystem   = d.filesystem
          options      = d.options == "" ? "defaults" : d.options
          owner        = d.owner
          group        = d.group
          mode         = d.mode
          wait_seconds = d.wait_seconds
        })
      },
      {
        path        = "/etc/systemd/system/disk-${k}.service"
        permissions = "0644"
        owner       = "root:root"
        content = templatefile("${path.module}/templates/unit.service.tftpl", {
          description = "Format if empty and mount data disk ${k} on ${d.mountpoint}"
          after       = ""
          requires    = ""
          before      = ""
          exec        = "/usr/local/sbin/disk-setup-${k}"
          timeout     = d.wait_seconds + 300
        })
      },
    ]
  ])

  bind_files = flatten([
    for k, b in var.bind_mounts : [
      {
        path        = "/usr/local/sbin/bind-mount-${k}"
        permissions = "0755"
        owner       = "root:root"
        content = templatefile("${path.module}/templates/bind-mount.sh.tftpl", {
          source = "${trimsuffix(try(local.disks[b.disk].mountpoint, "/missing"), "/")}/${b.path}"
          target = b.target
        })
      },
      {
        path        = "/etc/systemd/system/bind-${k}.service"
        permissions = "0644"
        owner       = "root:root"
        content = templatefile("${path.module}/templates/unit.service.tftpl", {
          description = "Bind-mount ${b.path} of disk ${b.disk} on ${b.target}"
          after       = "disk-${b.disk}.service"
          requires    = "disk-${b.disk}.service"
          before      = "docker.service containerd.service"
          exec        = "/usr/local/sbin/bind-mount-${k}"
          timeout     = 120
        })
      },
    ]
  ])

  units = concat(
    [for k in sort(keys(var.disks)) : "disk-${k}.service"],
    local.bind_units,
  )

  config = merge(
    {
      hostname          = var.hostname
      preserve_hostname = false
      timezone          = var.timezone
      package_update    = var.package_update
      package_upgrade   = var.package_upgrade
    },
    var.fqdn == null ? {} : { fqdn = var.fqdn },
    length(var.users) == 0 ? {} : {
      users = [
        for name in sort(keys(var.users)) : merge(
          {
            name                = name
            shell               = var.users[name].shell
            ssh_authorized_keys = var.users[name].ssh_authorized_keys
          },
          length(var.users[name].groups) == 0 ? {} : { groups = join(",", var.users[name].groups) },
          var.users[name].sudo ? { sudo = "ALL=(ALL) NOPASSWD:ALL" } : {},
        )
      ]
    },
    length(var.packages) == 0 ? {} : { packages = var.packages },
    length(var.write_files) + length(local.disk_files) + length(local.bind_files) == 0 ? {} : {
      write_files = concat(
        [for p in sort(keys(var.write_files)) : { path = p, content = var.write_files[p].content, owner = var.write_files[p].owner, permissions = var.write_files[p].permissions }],
        local.disk_files,
        local.bind_files,
      )
    },
    length(local.units) + length(var.runcmd) == 0 ? {} : {
      runcmd = concat(
        length(local.units) == 0 ? [] : [
          "systemctl daemon-reload",
          "systemctl enable --now ${join(" ", local.units)}",
        ],
        var.runcmd,
      )
    },
    var.extra_config,
  )
}
