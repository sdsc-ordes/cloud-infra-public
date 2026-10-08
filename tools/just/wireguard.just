set fallback := true
set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/wireguard.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

# Generate a WireGuard keypair (age-encrypted private key + public key).
[no-cd]
genkey user file:
    nu "{{nu_script}}" genkey "{{user}}" "{{file}}"

# Run wireguard commands like `up`/`down` for the specific component.
[no-cd]
quick comp *args:
    nu "{{nu_script}}" quick "$@"

# Gets the tunnel ip.
[private]
[no-cd]
tunnel-ip comp:
    nix eval --raw "{{root_dir}}/components/{{comp}}/system#nixosConfigurations.{{comp}}.config.settings.wireguard.tunnelIP"
