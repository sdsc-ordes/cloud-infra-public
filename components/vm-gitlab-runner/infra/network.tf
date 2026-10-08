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


# IPv4 Subnet for the internal network
resource "openstack_networking_subnet_v2" "main_v4" {
  name       = "${var.deploy_id}-subnet-main-v4"
  network_id = openstack_networking_network_v2.main.id
  cidr       = var.network_cidr_v4
  ip_version = 4
  dns_nameservers = [
    # Switch.ch
    "130.59.31.248",
    "130.59.31.251",

    # Google
    "8.8.8.8",
    # Cloudflare
    "1.1.1.1"
  ]
}

# Get the public ipv6 address pool.
# Because only these IPs on the router are routable to the internet.
data "openstack_networking_subnetpool_v2" "public_ipv6" {
  name = "public-ipv6"
}
# IPv6 Subnet for the internal network
resource "openstack_networking_subnet_v2" "main_v6" {
  name       = "${var.deploy_id}-subnet-main-v6"
  network_id = openstack_networking_network_v2.main.id

  ip_version = 6

  # Get an IP from the public ipv6 pool.
  subnetpool_id = data.openstack_networking_subnetpool_v2.public_ipv6.id
  # Let OpenStack allocate a /64 from the pool.
  prefix_length = 64

  ipv6_address_mode = "dhcpv6-stateful"
  ipv6_ra_mode      = "dhcpv6-stateful"

  dns_nameservers = [
    # Switch.ch
    "2001:620:0:ff::2",
    "2001:620:0:ff::3",

    # Google
    "2001:4860:4860:0:0:0:0:8888",
    # Cloudflare
    "2606:4700:4700:0:0:0:0:1111",
  ]
}

# Router connecting the internal network to the external network
resource "openstack_networking_router_v2" "main" {
  name                = "${var.deploy_id}-router-main"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Router interface to the internal network (IPv4)
resource "openstack_networking_router_interface_v2" "main_v4" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.main_v4.id
}

# Router interface to the internal network (IPv6)
resource "openstack_networking_router_interface_v2" "main_v6" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.main_v6.id
}
