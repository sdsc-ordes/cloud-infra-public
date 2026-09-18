variable "deploy_id" {
  type        = string
  description = "Set by tooling! The internal unique deploy id of these resources."
}

variable "kubeconfig" {
  type        = string
  description = "The kubeconfig file to authenticate to kubernetes."
}

variable "branch" {
  type        = string
  description = "The branch on which fluxcd does reconciliation."
  default     = "main"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster."
}

variable "cluster_context" {
  type        = string
  description = "Cluster context/ID in the kube config."
}

variable "github_token" {
  type        = string
  description = "Personal access token that has `repo` rights."
  sensitive   = true
}

variable "github_owner" {
  type        = string
  description = "GitHub owner where the repository used for flux is located."
}
