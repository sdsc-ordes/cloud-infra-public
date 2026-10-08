set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/nix.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

# Enter the Nix development shell `shell` and execute the command `args`.
[no-cd]
develop *args:
    nu "{{nu_script}}" develop "$@"

# Start a Nix interpreter with the flake loaded.
[no-cd]
repl:
    nix repl --accept-flake-config "{{root_dir}}/tools/nix"

# Build a package in the `packages` output of `flake.nix`.
alias build := package
[no-cd]
package attrname *args:
    nu "{{nu_script}}" package "$@"

# Show all packages.
[no-cd]
show:
    nix flake show "{{root_dir}}/tools/nix"
