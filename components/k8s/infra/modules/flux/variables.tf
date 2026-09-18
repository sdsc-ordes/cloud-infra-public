variable "branch" {
  default     = "main"
  description = "branch name"
  type        = string
}

variable "cluster_green_light" {
  default     = ["true"]
  description = "To have this module depend on the last step of the cluster creation."
  type        = list(string)
}

variable "enable_dedicated_nodes" {
  default     = false
  description = "Run Flux on dedicated nodes: this adds the toleration 'dedicated=essential:NoSchedule' and the nodeSelector 'dedicated=essential' to the Flux pods."
  type        = bool
}

variable "github_environment" {
  type = string
}

variable "github_owner" {
  description = "Github owner for terraform provider 'integration/github'."
  type        = string
}

# variable "github_token" {
#   description = "Github token for terraform procvider 'integration/github'."
#   type        = string
# }

variable "repository_name" {
  description = "Github repository name (github slug: `$github_owner/$repository_name`) which fluxcd syncs."
  type        = string
}

variable "sops-key" {
  description = "Base64 encoded age identity needed by flux to decrypt the secrets through SOPS."
  type        = string
}

variable "target_path" {
  description = "Flux sync target path."
  type        = string
}

variable "patches" {
  default     = []
  description = "Names of patch files to be added to flux system."
  type        = list(string)
}
