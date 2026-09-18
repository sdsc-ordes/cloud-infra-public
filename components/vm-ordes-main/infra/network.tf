# Network, subnet, and router for the deployment.

# Reference to the external network for router gateway (e.g., public internet)
data "openstack_networking_network_v2" "external" {
  name = "public"
}

data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

# Main internal network for the deployment
resource "openstack_networking_network_v2" "main" {
  name           = "${var.deploy_id}-network-main"
  admin_state_up = true
}

# Subnet for the internal network
resource "openstack_networking_subnet_v2" "main" {
  name       = "${var.deploy_id}-subnet-main"
  network_id = openstack_networking_network_v2.main.id
  cidr       = var.network_cidr
  ip_version = 4
  # TODO: Check if we need here a different cloud.switch.ch DNS name (check resolvd on a VM)
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

# Router connecting the internal network to the external network
resource "openstack_networking_router_v2" "main" {
  name                = "${var.deploy_id}-router-main"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Router interface to the internal network
resource "openstack_networking_router_interface_v2" "main" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.main.id
}
