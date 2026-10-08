set fallback := true
set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/openstack.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

# Run openstack CLI commands.
run *args:
    just sops::exec-env openstack-cli openstack "$@"

# Close the ssh port on a server.
close-ssh deploy_id:
    nu "{{nu_script}}" close-ssh "{{deploy_id}}"

# Open the ssh port on a server.
open-ssh deploy_id:
    nu "{{nu_script}}" open-ssh "{{deploy_id}}"
