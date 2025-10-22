##########################################################
# Create Volumes resources when specifiying create = true  
##########################################################

resource "openstack_blockstorage_volume_v3" "volumes-root" {
  for_each = {
    for instance in var.instances : instance.name => {
      name  = instance.root_volume.name
      size  = instance.root_volume.size
      az    = instance.root_volume.az
      image = instance.root_volume.image
    } if instance.image == null && try(instance.root_volume.create, false)
  }

  name              = each.value.name
  size              = each.value.size
  availability_zone = each.value.az
  image_id          = each.value.image != null ? each.value.image : null

  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_blockstorage_volume_v3" "volumes-data" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for volume in instance.data_volumes : {
          instance_name = instance.name
          name          = volume.name
          size          = volume.size
          az            = volume.az
          image         = contains(keys(volume), "image") ? volume.image : null
        } if volume.create
      ]
    ]) : "${item.instance_name}-${item.name}" => item
  }

  name              = each.value.name
  size              = each.value.size
  availability_zone = each.value.az
  image_id          = each.value.image != null ? each.value.image : null

  lifecycle {
    prevent_destroy = true
  }
}


####################################################################
# Import Volumes as data resources when specifiying create = false 
####################################################################

data "openstack_blockstorage_volume_v3" "volumes-root" {
  for_each = {
    for instance in var.instances : instance.name => instance if instance.image == null && try(!instance.root_volume.create, false)
  }

  name = each.value.root_volume.name
}

data "openstack_blockstorage_volume_v3" "volumes-data" {
  for_each = {
    for item in flatten([
      for instance in var.instances : [
        for volume in instance.data_volumes : {
          name          = volume.name
          instance_name = instance.name
        } if !volume.create
      ]
    ]) : "${item.instance_name}-${item.name}" => item
  }

  name = each.value.name
}
