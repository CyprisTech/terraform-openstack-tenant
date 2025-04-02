####################
# Images to push
####################

resource "openstack_images_image_v2" "images" {
  for_each = { for image in var.images: image.name => image }
  name             = each.value.name
  image_source_url = each.value.image_source_url
  container_format = each.value.container_format
  disk_format      = each.value.disk_format
  visibility       = "shared"

  #properties = {
  #  key = "value"
  #}
}
