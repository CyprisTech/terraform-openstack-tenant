resource "null_resource" "docker_volumes_bind_mount" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for bind_mount in instance.bind_mounts : {
          instance_name = instance.name
          host_ip       = local.instance_admin_ip_address[instance.name].ip_address
          username      = bind_mount.username
          uid           = bind_mount.uid
          gid           = bind_mount.gid
          path          = bind_mount.path
          conf_file     = lookup(bind_mount, "conf_src_file", null)
        }
      ] if can(instance.bind_mounts)
    ]) : "${item.instance_name}-${item.path}" => item
  }
  depends_on = [null_resource.instance_volumes_setup]

  connection {
    type = "ssh"
    user = var.ssh_user
    host = each.value.host_ip
  }

  provisioner "remote-exec" {
    inline = [
      "getent group ${each.value.username} || sudo groupadd --system --gid ${each.value.gid} ${each.value.username}",
      "id -u ${each.value.username} >/dev/null 2>&1 || sudo useradd --system --no-create-home --uid ${each.value.uid} --gid ${each.value.gid} ${each.value.username}",
      "sudo mkdir -p ${each.value.path}",
      "sudo chown -R ${each.value.username}: ${each.value.path}"
    ]
  }

  triggers = {
    provisioner_update = "v1" # Update this value to force re-execution
  }
}

resource "null_resource" "docker_service_deploy_conf_file" {
  for_each = {
    for item in flatten([
      for instance in local.instances : [
        for bm in instance.bind_mounts : {
          instance_name = instance.name
          conf_filepath = "files/${bm.conf_src_file}"
          conf_filename = element(split("/", bm.conf_src_file), length(split("/", bm.conf_src_file)) - 1)
          path          = bm.path
          host_ip       = local.instance_admin_ip_address[instance.name].ip_address
        } if lookup(bm, "conf_src_file", null) != null
      ] if can(instance.bind_mounts)
    ]) : item.instance_name => item
  }
  depends_on = [null_resource.docker_volumes_bind_mount]

  connection {
    type = "ssh"
    user = var.ssh_user
    host = each.value.host_ip
  }

  provisioner "file" {
    source      = "${path.module}/${each.value.conf_filepath}"
    destination = "/tmp/${each.value.conf_filename}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/${each.value.conf_filename} ${each.value.path}",
      "sudo chown 65534:65534 ${each.value.path}/${each.value.conf_filename}",
      "sudo chmod 644 ${each.value.path}/${each.value.conf_filename}"
    ]
  }
  triggers = {
    provisioner_update = "v1" # Update this value to force re-execution
  }
}

resource "local_file" "bind_mount_conf_file_template_rendered" {
  for_each = {
    for item in flatten([
      for instance in local.instances : [
        for bm in instance.bind_mounts : {
          instance_name = instance.name
          conf_filepath = "${bm.conf_template_file}"
          path          = bm.path
          host_ip       = local.instance_admin_ip_address[instance.name].ip_address
          template_vars = bm.template_vars
        } if lookup(bm, "conf_template_file", null) != null
      ] if can(instance.bind_mounts)
    ]) : item.instance_name => item
  }

  filename   = "${path.module}/templates_rendered/${each.value.conf_filepath}"
  content    = templatefile("${path.module}/templates/${each.value.conf_filepath}", each.value.template_vars)
  depends_on = [null_resource.docker_volumes_bind_mount]
}
