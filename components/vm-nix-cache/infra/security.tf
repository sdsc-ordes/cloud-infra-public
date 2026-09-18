# Management security group (SSH restricted to specific IP ranges)
resource "openstack_networking_secgroup_v2" "management" {
  name        = "${var.deploy_id}-secgroup-management"
  description = "Management access (SSH)"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.management.id
}
