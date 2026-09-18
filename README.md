<img src="docs/assets/cloud-infra-logo.svg" width="50%">

# cloud-infra

Shared, declarative cloud infrastructure for SDSC.

This repository contains reusable, project-agnostic infrastructure components developed collaboratively across the SDSC Infrastructure and Engineering teams, with operational responsibility held by the SDSC Infrastructure Team.
 
> **Repository status:** This repository is a public reference mirror. Active development, reviews, and operational changes are managed in the private working repository.

## What this repo contains

The repository defines infrastructure-as-code for shared cloud resources across supported environments, including SWITCH and Azure.

The focus is on reusable infrastructure that is not tied to a specific project. Project-specific application configuration should normally live with the corresponding project or service.

Current components include:

- [k8s](components/k8s)
- [vm-ordes-main development VM](components/vm-ordes-main)
- [vm-gitlab-runner](components/vm-gitlab-runner)
- [vm-nix-cache](components/vm-nix-cache)

## Operating model

Infrastructure in this repository is maintained declaratively and reviewed through version control.

The SDSC Infrastructure Team is responsible for operating the underlying infrastructure, while patterns, components, and improvements can be developed collaboratively with Engineering and other teams.

Where possible, we provide documented, reusable interfaces and examples so that teams can consume infrastructure capabilities directly without requiring project-specific setup or unnecessary manual handovers.

## Getting started

To learn how to use this repository, you may want to read the following:

- [👤 User Guidelines](docs/user.md) to access existing resources.
- [🧑‍🔧 Contributing Guidelines](docs/CONTRIBUTING.md) to add your own components
  or contribute to this repository.
- [🛡️ Security Guidelines](docs/SECURITY.md) for security-related questions.

## Principles

The repository follows a few simple principles:

- **Declarative by default** — infrastructure changes should be reproducible and version-controlled.
- **Reusable over project-specific** — common capabilities should be implemented once and shared.
- **Clear ownership** — operational responsibilities and interfaces should be explicit.
- **Open collaboration** — infrastructure patterns can be co-developed across teams.
- **Self-service where practical** — teams should be able to consume documented infrastructure capabilities without unnecessary handovers.
- **Secure by design** — access and infrastructure changes should follow documented security practices.
 
Copyright (c) 2026 Swiss Data Science Center (SDSC)
