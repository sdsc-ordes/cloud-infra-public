set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/k8s.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

[group('k8s')]
[no-cd]
kubectl *args:
    nu "{{nu_script}}" kubectl "$@"

[group('k8s')]
[no-cd]
flux9s *args:
    nu "{{nu_script}}" flux9s "$@"

[group('k8s')]
[no-cd]
k9s *args:
    nu "{{nu_script}}" k9s "$@"

# Deploy a swiss-army-knife container with all stupid tools.
[group('k8s')]
[no-cd]
deploy-army-knife comp namespace *args:
    nu "{{nu_script}}" deploy-army-knife "{{comp}}" "{{namespace}}" "$@"
