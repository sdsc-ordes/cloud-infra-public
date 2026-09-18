# Virtual Machine `vm-gitlab-runner`

This component contains the Gitlab Runner VM.

It consists of:

- `infra`: Infrastructure as code written in terraform.
- `system`: The declarative NixOS operating system.

External secrets and environment variables are declared in `deploy.yaml`. To
understand how secrets are loaded, look at the `secrets` component.
