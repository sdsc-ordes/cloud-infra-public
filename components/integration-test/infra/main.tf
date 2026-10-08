# Provider-less config for the e2e tests (tests/e2e.nu): local state, no
# network. The output must match ip.public in ../deploy.yaml so a test apply
# leaves the tree unchanged.

variable "env" {
  type = string
}

variable "comp" {
  type = string
}

variable "deploy_id" {
  type = string
}

output "public_floating_ip" {
  value = "192.0.2.1"
}
