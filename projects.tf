##################
# Create Projects
##################

resource "openstack_identity_project_v3" "projects" {
  for_each = { for project in var.projects : project.name => project }

  name        = each.value.name
  description = each.value.description
  enabled     = each.value.enabled
}


data "openstack_identity_project_v3" "projects" {
  for_each = { for project in var.data.projects : project => {} }
  name = each.key
}

data "openstack_identity_role_v3" "admin" {
  name = "admin"
}
