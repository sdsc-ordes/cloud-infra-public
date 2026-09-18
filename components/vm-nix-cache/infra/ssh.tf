resource "openstack_compute_keypair_v2" "ssh_key_init_pub" {
  name       = "${var.deploy_id}-key-init-pub"
  public_key = var.ssh_key_init_pub
}
