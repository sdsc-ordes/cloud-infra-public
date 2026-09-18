# Boot volume for the application instance
resource "openstack_blockstorage_volume_v3" "boot_volume" {
  name                 = "${var.deploy_id}-volume-boot"
  size                 = var.boot_disk_size
  volume_type          = "performance"
  image_id             = var.image_id
  enable_online_resize = true
  description          = "Boot volume for ${var.deploy_id}"
}
