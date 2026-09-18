# User Guidelines

> [!IMPORTANT]
>
> Whenever possible, projects should deploy their stacks on existing shared
> resources (compose or k8s) instead of deploying a dedicated VM. This minimizes
> cost and management overhead.

To deploy your project workload, always prefer k8s to VMs. This is more
cost-efficient and easier to manage on the long term.

If required, a project may manage its own compute resources on SWITCH Cloud
outside of this repo. These resources should be deployed to OpenStack through
terraform's openstack provider. It is the project's responsibility to deploy and
manage them and its own `.tfstate` file and persist it in a project-dedicated S3
bucket in the SWITCH cloud project.

## Pre-Requisites

To decrypt secret files, you need to set up the development environment as
described in [CONTRIBUTING guidelines](CONTRIBUTING.md).

### Accessing Secrets

As a user of an existing component, you only need access to the secrets inherent
to that component.

1. Identify what files you need access to. This will most likely be:

- SSH key in the component you will use.

2. Generate your age key pair and add your **public** age key to `users` in
   `components/secrets/config.toml`.

   > [!TIP]
   >
   > Use
   > `just sops::generate-key ~/.config/sops/sdsc-ordes-cloud-infra.agekey.age`
   > to generate a passphrase-encrypted age key, then point `SOPS_AGE_KEY_FILE`
   > at that file in the root [`.env`](../.env.tmpl) (see step 6). sops prompts
   > for the passphrase when it needs the key.

3. Generate your personal Wireguard (VPN) key:

   ```bash
   # <secret-config-user> is your user in ./components/secrets/config.toml.
   just wg::genkey <secret-config-user> ~/.config/wireguard/sdsc-ordes-cloud-infra
   ```

   This will create two files `~/.config/wireguard/sdsc-ordes-cloud-infra.pub`
   and `~/.config/wireguard/sdsc-ordes-cloud-infra.age` (encrypted with your age
   key in the step before.)

   **Copy the **public** key in the `*.pub` to `components/secrets/config.toml`
   under your user. Add the name of the components you need access to under
   componentAccess**

4. Update creation rules in `components/secrets/secrets.yaml` by adding your
   username for files you **need** access to.
   - Example: For `vm-ordes-main` you need to be able to decrypt the SSH keys of
     some users (`shine`, `across`, etc.) to be able to connect.

   You might need to add a new creation rule for this. Make sure to always add
   your username to those rules using `add_keys(["<username>"])`.

5. Open a PR with the updated `config.toml` and `secrets.yaml` file. An admin
   will be tagged automatically.

6. An admin will re-encrypt the secrets in the repo to let you decrypt them, and
   push the updated secrets.

7. Copy `.env.tmpl` to `.env` and adjust the path to your `age` private key, if
   needed and Wireguard private key.

8. Pull the new secrets and run `just sops::edit <secret-file>` to edit the
   value of the secrets.

   > [!WARNING]
   >
   > Do not store these secrets in your password manager.

### Wireguard Setup

To set up, see [wireguard](wireguard.md).

> [!NOTE]
>
> Once the Wireguard tunnel is up, you may also SSH into a VM using
> `just ssh-vm <component> <ssh-user>`.

## Deploying VMs

These are the pre-requisites to create a new VM component. This requires
additional admin rights to deploy the resources.

1. Get access to decrypt the Openstack token (ask an Openstack admin).
2. Declaratively configure your resources in terraform configurations. You can
   start by copying and editing an existing VM in this repository.
3. Define what is inside your VM. There are many options to bootstrap the VM,
   including `cloud-init`, or just using a custom ISO, but we suggest using
   `nixos-anywhere` and `deploy-rs` like in the example above.

All common deployments share a common 2-step process:

1. Deploy resources with Terraform's Openstack provider.
2. Bootstrap VMs with `nixos-anywhere`.

Subsequent system changes can be managed with `nix` using `deploy-rs`, thus
requiring no redeploy with terraform.

This two step process is automated with `just deploy <component>`.

For more information on working in this repository, see
[CONTRIBUTING](CONTRIBUTING.md) guidelines.

## Security

Public facing projects require specific network configuration (router, firewall,
...) and should always be reviewed by >1 SWITCH Cloud admins.

See [SECURITY.md](SECURITY.md).

## Deploying on k8s

As a team member, you are welcome to deploy your workloads on k8s. This is done
declaratively via GitOps. You should add your app deployment manifests in a PR.

For details on how to do this, see the
[`k8s/manifests`](/components/k8s/manifests/README.md) documentation.

## External collaborators

External collaborators are not granted access to this GitHub organization or
repository and are therefore unable to access or decrypt the repository's
encrypted files and secrets like internal members can.

To invite external collaborators to work on a virtual machine, you will need to
share the required SSH keypair with them (user or project) and the Wireguard
config.

> [!IMPORTANT]
>
> The Wireguard configuration and SSH private key are sensitive. Make sure to
> always share them in an encrypted format (with GPG or age), especially when
> sending them through insecure channels such as email or slack. If needed, ask
> the recipient to generate a GPG or age keypair first and share their public
> key with you, so you can encrypt those files for them.

Upon offboarding external collaborators, make sure to:

- revoke or replace the SSH key that was shared with them with a new one
  (`ssh-keygen`) and open a PR, and
- revoke their WireGuard access by removing their client/peer from the WireGuard
  configuration, rotating any shared WireGuard secrets as needed, and
  applying/redeploying the updated VPN configuration.
