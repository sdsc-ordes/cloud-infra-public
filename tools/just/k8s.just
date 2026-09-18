set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/k8s.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

[group('k8s')]
kubectl *args:
    nu "{{nu_script}}" kubectl "$@"

[group('k8s')]
flux9s *args:
    nu "{{nu_script}}" flux9s "$@"

[group('k8s')]
k9s *args:
    nu "{{nu_script}}" k9s "$@"

# Deploy a swiss-army-knife container with all stupid tools.
[group('k8s')]
deploy-army-knife comp namespace *args:
    nu "{{nu_script}}" deploy-army-knife "{{comp}}" "{{namespace}}" "$@"
