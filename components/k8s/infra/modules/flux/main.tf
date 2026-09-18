terraform {
  required_version = ">=1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3"
    }
  }
}

# SSH Public key to verify key of github.com.
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

# Secrets for fluxcd.
# ==============================================================
# Special github ssh key for flux to access repo
# Generates an ECDSA private/public key pair.
# The public key will be registered below as a Github deploy key.
resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}
# Register the public key `tls_private_key.main` as a deploy key.
data "github_repository" "main" {
  full_name = "${var.github_owner}/${var.repository_name}"
}
resource "github_repository_deploy_key" "main" {
  title      = "flux-${var.github_environment}"
  repository = data.github_repository.main.name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}
# Add the  `tls_private_key` as a kubernetes secret
# which `flux2-sync` will use.
resource "kubernetes_secret" "main" {
  metadata {
    name      = helm_release.flux2.namespace
    namespace = helm_release.flux2.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }

  depends_on = [helm_release.flux2]
}

# Define a kubernetes secret for SOPS decryption
# which is configured in `flux2-sync` will use below.
resource "kubernetes_secret" "sops-key" {
  data = {
    "sops.agekey" = base64decode(var.sops-key)
  }
  metadata {
    name      = "sops-age"
    namespace = helm_release.flux2.namespace
  }

  depends_on = [helm_release.flux2]
}
# ==============================================================

resource "helm_release" "flux2" {
  name = "flux2"

  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = "true"
  version          = "2.16.0"
  namespace        = "flux-system"
  wait             = false

  # Helm controller
  set {
    name  = "helmController.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "helmController.resources.limits.memory"
    value = "2Gi"
  }
  set {
    name  = "helmController.resources.requests.cpu"
    value = "0.25"
  }
  set {
    name  = "helmController.resources.requests.memory"
    value = "256Mi"
  }
  # Image automation controller
  set {
    name  = "imageAutomationController.create"
    value = "false"
  }
  # Image reflection controller
  set {
    name  = "imageReflectionController.create"
    value = "false"
  }
  # Kustomize controller
  set {
    name  = "kustomizeController.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "kustomizeController.resources.limits.memory"
    value = "2Gi"
  }
  set {
    name  = "kustomizeController.resources.requests.cpu"
    value = "0.25"
  }
  set {
    name  = "kustomizeController.resources.requests.memory"
    value = "256Mi"
  }
  # Notification controller
  set {
    name  = "notificationController.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "notificationController.resources.limits.memory"
    value = "2Gi"
  }
  set {
    name  = "notificationController.resources.requests.cpu"
    value = "0.25"
  }
  set {
    name  = "notificationController.resources.requests.memory"
    value = "256Mi"
  }
  # Source controller
  set {
    name  = "sourceController.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "sourceController.resources.limits.memory"
    value = "2Gi"
  }
  set {
    name  = "sourceController.resources.requests.cpu"
    value = "0.25"
  }
  set {
    name  = "sourceController.resources.requests.memory"
    value = "256Mi"
  }
  # Dedicated nodes
  values = var.enable_dedicated_nodes ? [
    file(path.module / "dedicated_nodes_values.yaml")
  ] : []
}


resource "helm_release" "flux2-sync" {
  name = "flux-system" # Necessary for migration

  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  version    = "1.6.2"
  namespace  = helm_release.flux2.namespace
  wait       = false

  set {
    name  = "gitRepository.spec.url"
    value = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  }
  set {
    name  = "gitRepository.spec.secretRef.name"
    value = kubernetes_secret.main.metadata[0].name
  }
  set {
    name  = "gitRepository.spec.ref.branch"
    value = var.branch
  }
  set {
    name  = "gitRepository.spec.interval"
    value = "1m0s"
  }
  set {
    name  = "kustomization.spec.path"
    value = var.target_path
  }
  set {
    name  = "kustomization.spec.interval"
    value = "10m0s"
  }

  depends_on = [helm_release.flux2]
}
