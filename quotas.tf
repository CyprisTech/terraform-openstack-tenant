##########################################
# Compute, Network, Block storage Quotas
##########################################

################################################################
###
### Default values, can be overrided into quotas.auto.tfvars
###
################################################################
###
### quotas = [
###     project_name = "admin",
###     compute = {
###         ram                 = 40960
###         cores               = 32
###         instances           = 20
###     },
###     network = {
###         floatingip          = 10
###         network             = 4
###         port                = 100
###         rbac_policy         = 10
###         router              = 4
###         security_group      = 10
###         security_group_rule = 100
###         subnet              = 8
###     },
###     volume  = {
###         volumes              = 10
###         snapshots            = 4
###         gigabytes            = 100
###         per_volume_gigabytes = 10
###         backups              = 4
###         backup_gigabytes     = 10
###     }
###]

##########################################
# Compute Quotas
##########################################

resource "openstack_compute_quotaset_v2" "quota" {
  for_each = { for quota in var.quotas : quota.project_name => quota if lookup(quota, "compute") != null }
  project_id = try(
    openstack_identity_project_v3.projects[each.key].id,
    data.openstack_identity_project_v3.projects[each.key].id
  )
  ram       = lookup(each.value.compute, "ram", 40960)
  cores     = lookup(each.value.compute, "cores", 32)
  instances = lookup(each.value.compute, "instances", 20)

  #  key_pairs            = 10
  #  server_groups        = 4
  #  server_group_members = 8
}

##########################################
# Network Quotas
##########################################

resource "openstack_networking_quota_v2" "quota" {
  for_each = { for quota in var.quotas : quota.project_name => quota if lookup(quota, "network") != null }
  project_id = try(
    openstack_identity_project_v3.projects[each.key].id,
    data.openstack_identity_project_v3.projects[each.key].id
  )
  floatingip          = lookup(each.value.network, "floatingip", 10)
  network             = lookup(each.value.network, "network", 4)
  port                = lookup(each.value.network, "port", 10)
  router              = lookup(each.value.network, "router", 4)
  security_group      = lookup(each.value.network, "security_group", 10)
  security_group_rule = lookup(each.value.network, "security_group_rule", 100)
  subnet              = lookup(each.value.network, "subnet", 8)
  rbac_policy         = lookup(each.value.network, "rbac_policy", 10)
  # subnetpool          = 2
}

##########################################
# Block Storage (Cinder) Quotas
##########################################

resource "openstack_blockstorage_quotaset_v3" "quota" {
  for_each = { for quota in var.quotas : quota.project_name => quota if lookup(quota, "volume") != null }
  project_id = try(
    openstack_identity_project_v3.projects[each.key].id,
    data.openstack_identity_project_v3.projects[each.key].id
  )
  volumes              = lookup(each.value.volume, "volumes", 10)
  snapshots            = lookup(each.value.volume, "snapshots", 4)
  gigabytes            = lookup(each.value.volume, "gigabytes", 100)
  per_volume_gigabytes = lookup(each.value.volume, "per_volume_gigabytes", 10)
  backups              = lookup(each.value.volume, "backups", 4)
  backup_gigabytes     = lookup(each.value.volume, "backup_gigabytes", 10)

  # groups = 100
  # volume_type_quota = {
  #   volumes_ssd = 30
  #   gigabytes_ssd = 500
  #   snapshots_ssd = 10
  # }
}
