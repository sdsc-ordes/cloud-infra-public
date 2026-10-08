## VM

resource "openstack_compute_instance_v2" "machine" {
  name            = var.deploy_id
  flavor_name     = var.flavor
  security_groups = ["default", resource.openstack_networking_secgroup_v2.management.name]

  key_pair = resource.openstack_compute_keypair_v2.ssh_key_init_pub.name

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.boot_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.public_port.id
  }
}

moved {
  from = openstack_compute_instance_v2.vm-ordes-main
  to   = openstack_compute_instance_v2.machine
}
