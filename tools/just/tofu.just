set fallback := true
set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/tofu.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

# Run a tofu command with the component's vars and secrets loaded via sops.
[no-cd]
run comp *args:
    nu "{{nu_script}}" run "$@"

# Initialize terraform.
[no-cd]
init comp *args:
    just tofu::run "{{comp}}" init --reconfigure "${@:2}" >&2

# Validate the terraform configuration.
[no-cd]
validate comp *args:
    just tofu::run "{{comp}}" validate "${@:2}"

# Preview the infrastructure changes.
[no-cd]
plan comp *args:
    just tofu::init "{{comp}}" "${@:2}"
    just tofu::run "{{comp}}" plan "${@:2}"

# Get all outputs from the deployment.
[no-cd]
output comp *args:
    just tofu::init "{{comp}}" "${@:2}"
    just tofu::run "{{comp}}" output --json "${@:2}"

# Apply the infrastructure changes and persist the new IP to deploy.yaml.
[no-cd]
apply comp *args:
    nu "{{nu_script}}" apply "$@"

# Destroy the infrastructure.
[no-cd]
destroy comp *args:
    just tofu::init "{{comp}}" "${@:2}"
    just tofu::run "{{comp}}" destroy "${@:2}"

# Continuously validate terraform on file change.
# FIXME: Does not work for k8s component
[no-cd]
watch comp *args:
    #!/usr/bin/env bash
    set -eu -o pipefail
    tofu_dir="{{root_dir}}/components/{{comp}}/infra"

    fd --extension tf --type file . "$tofu_dir" \
        | entr just tofu validate "{{comp}}" "${@:2}"
