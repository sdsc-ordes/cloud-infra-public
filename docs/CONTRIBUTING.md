# How to Contribute

## Development Environment

To work in this repository, you need to set up 2 tools:

- The nix package manager.
- The direnv tool, which will activate the nix shell when you cd into the repo.
  Set up nix to always work in the development shell. It is recommended to

See the relevant page of
<a href="https://swissdatasciencecenter.github.io/best-practice-documentation/docs/dev-enablement/nix-and-nixos#installing-direnvThttps://swissdatasciencecenter.github.io/best-practice-documentation/docs/dev-enablement/nix-and-nixos"><img src="https://swissdatasciencecenter.github.io/best-practice-documentation/img/sdsc-logo.svg" width="16px">
SDSC Best Practice Documentation</a> for instructions to set up these tools.

We use just recipes for operations in the repository, type `just` to see
available recipes.

## Conventions

### Naming

- Components for virtual machines are named `component-name := vm-<name>`.

- Terraform resources must be prefixed with the `var.deploy_id`:

  ```nix
  deploy_id := <component-name>-<env>
  ```

  **Note:** This variable is always set on the command line to any
  `just tofu ...` command.
  - `env` is the environment if you use it. Must correspond to a
    `components/<component>/infra/envs/<env>.tfvars` file.

  Example: `vm-ordes-main-dev-port-public` where
  `deploy_id := vm-ordes-main-dev`.

## Structure

All the tooling used to work in the repository is defined in `tools/`. The
actual infrastructure as code is separated into components under `components/`.

New VMs can be declared in `components/vm-<machine-name>/infra/`.

The NixOS configuration of the machine should be defined inside
`components/vm-<machine-name>/system/`. Reusable machine-independent NixOS
modules can be defined in `components/common-nix/modules/`

Every deployable machine configuration should be imported in the root flake at
`components/vm-<machine-name>/flake.nix`.

## Network Architecture

Currently, each VM lives in its own network for simplicity and security (network
segmentation). Only the wireguard port is public facing. That means each VM
operates its own wireguard server.

## Secrets Management

Secrets must be encrypted and stored **only** in the `secrets` component. Either
under `components/secrets/<component-name>/` for component-specific secrets, or
dedicated subdirectories for component-agnostic secrets (e.g.
`components/secrets/wireguard/`).

> [!IMPORTANT]
>
> **Never** edit encrypted secret files (`*.sops.*`) directly, always with
> `just sops::edit`.

In order to be able to decrypt them, your key must be added to
`components/secrets/config.toml`, and the file must be re-encrypted with your
key by an existing contributor by doing `just sops::re-encrypt false`

> [!IMPORTANT]
>
> For a VM with NixOS, you need to add the machine to
> `components/secrets/config.toml` in order to store the host's age key to
> re-encrypt the secrets when deploying.

For more information on this process, see [🛡️ SECURITY guidelines](SECURITY.md).

## Terraform

Always make sure the `.tfstate` file is stored on S3 and is scoped by
machine/env combination. Machine variables can be stored in `.tfvars` file if
relevant, but sensitive values should never be in there (see secrets management
section).

## Kubernetes

The `k8s` component hosts the IaC clusters setup under `infra`, and the gitops
manifests for FluxCD under `manifests'.

Kubernetes-specific documentation is embeded in the component:

- [`k8s`](/components/k8s/README.md)
- [`k8s/infra`](/components/k8s/infra/README.md)
- [`k8s/manifests`](/components/k8s/manifests/README.md)
