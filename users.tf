##################
# Create Users
##################

resource "openstack_identity_user_v3" "users" {
  for_each = { for user in var.users : user.name => user }

  name     = each.value.name
  password = each.value.password
  extra = {
    email = each.value.email
  }
  enabled = each.value.enabled
}

