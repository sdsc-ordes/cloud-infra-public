# Security Policies

This documents security policies and practices for this repository.

## Reporting an Issue

If you encounter a security-related issue in the repo, contact one of the
administrators. You can find their names in the [CODEOWNERS](CODEOWNERS) file.

## Updating Secrets

Whenever a key is compromised, or a user is off-boarded, do the following:

1. Remove their `age` and `wireguard` public keys from
   `components/secrets/config.toml`.
2. Re-encrypt all repository secrets without their key and rotate the symmetric
   keys. This can be done with `just sops::re-encrypt`.
3. Re-deploy the components to which the user's key had access with
   `just deploy <component-name>`. Pass env. variable `DEPLOY_RS_ARGS="..."` to
   control how to run `deploy-rs`. E.g. `DEPLOY_RS_ARGS=--boot` to only apply it
   to the next boot.

> [!IMPORTANT]
>
> Always ensure there are at least 2 people in the secret recipients to avoid
> losing access to it.

## Potential Improvements

- One Wireguard key per user.
  - Better for audit.
  - No private key needed in repo.
  - But more maintenance efforts (change keys in multiple places on
    on/off-boarding).
- One SSH key per user.
  - Same as Wireguard.
- Bastion host for Wireguard.
  - Minimize redeploy effort when updating Wireguard keys.
  - Better for security: single minimal machine as public facing.
  - But no network segmentation (all machines in a shared network).
