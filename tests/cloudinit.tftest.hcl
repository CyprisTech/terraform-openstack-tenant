# The module only renders a document: no provider is involved, so the runs
# apply and inspect the output.

variables {
  hostname = "app-1"
  users    = { ops = { ssh_authorized_keys = ["ssh-ed25519 AAAA example"], sudo = true, groups = ["docker", "adm"] } }
  packages = ["htop"]
  disks = {
    data = { device = "/dev/vdb", mountpoint = "/srv/data", owner = "ops", mode = "0750" }
    logs = { device = "/dev/vdc", filesystem = "xfs", mountpoint = "/var/log/app" }
  }
  bind_mounts = { docker = { disk = "data", path = "docker", target = "/var/lib/docker" } }
  runcmd      = ["echo done"]
}

run "renders_a_cloud_config" {
  module {
    source = "./modules/cloudinit"
  }

  assert {
    condition     = startswith(output.rendered, "#cloud-config\n")
    error_message = "The document must start with the cloud-config header."
  }

  assert {
    condition     = yamldecode(trimprefix(output.rendered, "#cloud-config\n")).hostname == "app-1"
    error_message = "The rendered YAML must decode to the configuration."
  }

  assert {
    condition     = output.config.users[0].sudo == "ALL=(ALL) NOPASSWD:ALL" && output.config.users[0].groups == "docker,adm"
    error_message = "Users get sudo and groups as cloud-init expects them."
  }

  assert {
    condition = toset([for f in output.config.write_files : f.path]) == toset([
      "/usr/local/sbin/disk-setup-data", "/etc/systemd/system/disk-data.service",
      "/usr/local/sbin/disk-setup-logs", "/etc/systemd/system/disk-logs.service",
      "/usr/local/sbin/bind-mount-docker", "/etc/systemd/system/bind-docker.service",
    ])
    error_message = "Each disk and bind mount gets a script and a systemd unit."
  }

  assert {
    condition     = jsonencode(output.config.runcmd) == jsonencode(["systemctl daemon-reload", "systemctl enable --now disk-data.service disk-logs.service bind-docker.service", "echo done"])
    error_message = "Units are enabled before user commands."
  }

  assert {
    condition     = strcontains([for f in output.config.write_files : f.content if f.path == "/usr/local/sbin/disk-setup-logs"][0], "mkfs.xfs -L \"$label\"")
    error_message = "The file system type is passed to mkfs."
  }

  assert {
    condition     = strcontains([for f in output.config.write_files : f.content if f.path == "/etc/systemd/system/bind-docker.service"][0], "Requires=disk-data.service")
    error_message = "A bind mount requires its disk."
  }
}

run "minimal_document" {
  module {
    source = "./modules/cloudinit"
  }

  variables {
    users       = {}
    packages    = []
    disks       = {}
    bind_mounts = {}
    runcmd      = []
  }

  assert {
    condition     = !contains(keys(output.config), "users") && !contains(keys(output.config), "write_files") && !contains(keys(output.config), "runcmd")
    error_message = "Empty sections are omitted, so the distribution defaults apply."
  }
}

run "rejects_long_xfs_label" {
  command = plan

  module {
    source = "./modules/cloudinit"
  }

  variables {
    disks       = { this-label-is-too-long = { device = "/dev/vdb", filesystem = "xfs", mountpoint = "/srv" } }
    bind_mounts = {}
  }

  expect_failures = [var.disks]
}

run "rejects_bind_mount_on_unknown_disk" {
  command = plan

  module {
    source = "./modules/cloudinit"
  }

  variables {
    bind_mounts = { bad = { disk = "nope", path = "x", target = "/x" } }
  }

  expect_failures = [output.rendered]
}
