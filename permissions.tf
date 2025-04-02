####################################
# User Roles assignment to Project
###################################

resource "openstack_identity_role_assignment_v3" "user_project_roles" {
  for_each = { for role in var.user_project_roles : "${role.user}-${role.project}" => role }

  user_id    = openstack_identity_user_v3.users[each.value.user].id
  project_id = data.openstack_identity_project_v3.projects[each.value.project].id
  role_id    = data.openstack_identity_role_v3.admin.id
}
