# Boot volume for the application instance
resource "openstack_blockstorage_volume_v3" "boot_volume" {
  name                 = "${var.deploy_id}-volume-boot"
  size                 = var.boot_disk_size
  volume_type          = "performance"
  image_id             = var.image_id
  enable_online_resize = true
  description          = "Boot volume for ${var.deploy_id}"
}

# Application data volume
resource "openstack_blockstorage_volume_v3" "app_data" {
  name                 = "${var.deploy_id}-volume-data"
  size                 = var.disk_size
  enable_online_resize = true
  description          = "Application data storage for ${var.deploy_id}"
}
