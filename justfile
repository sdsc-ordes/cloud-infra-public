set shell := ["bash", "-cue"]
set positional-arguments
set dotenv-load

root_dir := `git rev-parse --show-toplevel`
config_dir := root_dir / "tools/configs/"
nu_script := root_dir / "tools/nu/deploy.nu"

# Useful to apply special optional for `deploy` executable.
# Argument line like DEPLOY_RS_ARGS="--boot ..." properly quoted.
export DEPLOY_RS_ARGS := env("DEPLOY_RS_ARGS", "")

# Manage secrets using sops and age.
mod sops './tools/just/sops.just'
# Manage infrastructure as code with tofu.
mod tofu './tools/just/tofu.just'
# Manage nix flakes.
mod nix 'tools/just/nix.just'
# Manage openstack resources.
mod openstack 'tools/just/openstack.just'
# Some wireguard functions.
mod wg 'tools/just/wireguard.just'
# Some k8s functions.
mod k8s 'tools/just/k8s.just'

# Default recipe to list all recipes.
[private]
default:
    just --list

# Enter a development shell.
[group('general')]
develop:
    just nix::develop default

# Link tool config files into the repository root (runs on devshell entry).
[group('general')]
setup:
    nu tools/scripts/setup.nu

# Format the whole repository.
[group('general')]
format *args:
    treefmt "$@"

# Run the nushell tooling unit and end-to-end tests.
[group('general')]
test:
    nu tests/unit.nu
    nu tests/e2e.nu

# Statically check all nushell files.
[group('general')]
check:
    nu tools/scripts/check.nu

# Check for secret leaks.
[group('general')]
check-leaks *args:
    gitleaks git --config "{{config_dir}}/gitleaks.toml" {{args}}

# End-to-end deployment of the component.
[group('cloud')]
[confirm("This updates the deployment, are you sure? [y|N]")]
deploy comp *args:
    nu "{{nu_script}}" deploy "{{comp}}" "$@"

# Build the NixOS system.
[group('general')]
build-nixos comp:
    nu "{{nu_script}}" build-nixos "{{comp}}"

# Rebuild NixOS VM.
redeploy-nixos comp ip="" *ssh_args:
    nu "{{nu_script}}" redeploy-nixos "$@"

# Reboot the VM.
vm-reboot comp wireguard="true" *ssh_args:
    nu "{{nu_script}}" vm-reboot "$@"

# SSH into the machine.
[group('cloud')]
ssh-vm comp user="root" wireguard="true" *ssh_args:
    nu "{{nu_script}}" ssh-vm "$@"

# Add the SSH key of the component `comp` for user `user` to the ssh-agent.
[group('cloud')]
ssh-add comp user="root" wireguard="true":
    nu "{{nu_script}}" ssh-add "$@"

[private]
[confirm("This pushes to the public repo (no secrets), only admin should do that? [y|N]")]
update-public-mirror branch="main":
    nu "{{nu_script}}" update-public-mirror "{{branch}}"
