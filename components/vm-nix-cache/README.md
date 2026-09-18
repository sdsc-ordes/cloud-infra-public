# Virtual Machine `vm-nix-cache`

This component contains the shared Nix cache VM.

It consists of:

- `infra`: Infrastructure as code written in terraform.
- `system`: The declarative NixOS operating system.

External secrets and environment variables are declared in `deploy.yaml`. To
understand how secrets are loaded, look at the `secrets` component.

## Nix Derivation Signing

The derivations are signed by `vm-gitlab-runner` VM. To sign uploaded
derivations in the store do

```bash
just ssh-vm vm-nix-cache
sign-all-packages
```
