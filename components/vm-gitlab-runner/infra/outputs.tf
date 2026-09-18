output "public_floating_ip" {
  description = "The public floating IP address attached to the instance."
  value       = resource.openstack_networking_floatingip_v2.public_fip.address
}
