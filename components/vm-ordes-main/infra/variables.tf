variable "comp" {
  type        = string
  description = "Set by tooling! The component name."
}

variable "env" {
  type        = string
  description = "Set by tooling! The environment name (e.g., dev, prod) used as a prefix for all resources."
}

variable "deploy_id" {
  type        = string
  description = "Set by tooling! The internal unique deploy id of these resources."
}

variable "flavor" {
  type        = string
  description = "The flavor of the instance used for the VM"
}

variable "disk_size" {
  type        = number
  default     = 50
  description = "The size of the data disk of the instance in gigabytes."
}

variable "boot_disk_size" {
  type        = number
  default     = 20
  description = "The size of the boot disk of the instance in gigabytes."
}

variable "image_id" {
  type        = string
  default     = "09edb2d3-543c-4606-b417-e090e2c8780f"
  description = "Openstack image uuid. Use `just openstack::run image list --hidden` to find."
}

variable "network_cidr" {
  type        = string
  description = "The cidr block for the network. This determines the ip address range for the network."
}

variable "floating_ip" {
  type        = string
  description = "The floating IPs used to connect to the VM from the public internet."
}

variable "ssh_key_init_pub" {
  type        = string
  description = "The initial SSH public key on the VM which gets replaced by the NixOS install."
}

variable "launch_url" {
  type        = string
  description = "URL to application."
}
