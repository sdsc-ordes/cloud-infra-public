terraform {
  required_version = "1.8.5"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.0"
    }
  }
  backend "s3" {
    bucket                      = "terraform"
    key                         = "${var.deploy_id}.tfstate"
    endpoint                    = "https://zhw-a.s3.cloud.switch.ch"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

# Setup Github  integration provider
# to create resources there.
provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# Setup Kubernetes integration provider
# to create resources there.
provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = var.cluster_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.config/kube/${var.cluster_name}"
    config_context = var.cluster_context
  }
}

# Decrypt a file using carlpet/sops tf module
data "sops_file" "common_secrets" {
  source_file = "../../../../secrets/k8s/${var.cluster_name}/common.sops.yaml"
}

module "flux" {
  source             = "../../modules/flux"
  branch             = var.branch
  github_environment = var.cluster_name
  github_owner       = var.github_owner
  repository_name    = "cloud-infra"
  sops-key           = data.sops_file.common_secrets.data["flux-sops-key-b64e"]
  target_path        = "components/k8s/manifests/deployments/sck-sit-prod/main"

}
