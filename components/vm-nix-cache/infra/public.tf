# Public port for both management (SSH) and user (HTTPS) access
resource "openstack_networking_port_v2" "public_port" {
  name           = "${var.deploy_id}-port-public"
  network_id     = openstack_networking_network_v2.main.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default.id,
    openstack_networking_secgroup_v2.management.id,
  ]

  # IPv4
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.main_v4.id
  }

  # IPv6
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.main_v6.id
  }

  port_security_enabled = true
}

# Floating IP for public access (SSH and HTTPS)
resource "openstack_networking_floatingip_v2" "public_fip" {
  pool = data.openstack_networking_network_v2.external.name
}

# Associate floating IP with the public port
resource "openstack_networking_floatingip_associate_v2" "public_fip_assoc" {
  floating_ip = resource.openstack_networking_floatingip_v2.public_fip.address
  port_id     = openstack_networking_port_v2.public_port.id
}
