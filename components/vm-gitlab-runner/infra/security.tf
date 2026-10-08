# Management security group (SSH restricted to specific IP ranges)
resource "openstack_networking_secgroup_v2" "management" {
  name        = "${var.deploy_id}-secgroup-management"
  description = "Management access (VPN)"
}

# Allow wireguard
resource "openstack_networking_secgroup_rule_v2" "wireguard" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 51820
  port_range_max    = 51820
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.management.id
}
