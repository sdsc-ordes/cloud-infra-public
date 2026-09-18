set positional-arguments
set shell := ["bash", "-cue"]

root_dir := `git rev-parse --show-toplevel`
nu_script := root_dir / "tools/nu/sops.nu"

# Default recipe to list all recipes.
[private]
default:
    just --list -f {{source_file()}}

# Run any sops command.
[no-cd]
run *args:
    sops "$@"

# Create a passphrase-protected age key for sops at the given path.
[no-cd]
generate-key out:
    #!/usr/bin/env nu
    use "{{root_dir}}/tools/nu/lib/common.nu" *
    let out = ("{{out}}" | path expand)
    if ($out | path exists) { error make {msg: $"Key file already exists: ($out)"} }
    log info $"Generating passphrase-protected age key at ($out)."
    mkdir ($out | path dirname)
    # age-keygen prints a new identity; `age -p -e` passphrase-encrypts it.
    ^age-keygen | ^age -p -e | save --raw $out
    log info "Done. Point SOPS_AGE_KEY_FILE at this file."

# Encrypt all '*.dec.*' secret files.
encrypt-all:
    nu "{{nu_script}}" encrypt-all

# Encrypt a secrets file ('*.dec.*' -> '*.sops.*', removing the source).
[no-cd]
encrypt file:
    nu "{{nu_script}}" encrypt "{{file}}"

# Decrypt an encrypted file to stdout.
[no-cd]
decrypt file:
    sops decrypt "{{file}}"

# Edit an encrypted file in place.
[no-cd]
edit file:
    sops edit "{{file}}"

# Re-encrypt secrets based on secrets.yaml (without rotating the data key).
update:
    just sops::re-encrypt false

# Re-encrypt secrets based on secrets.yaml, optionally rotating the data key.
re-encrypt rotate="true":
    nu "{{nu_script}}" re-encrypt "{{rotate}}"

# Runs a command with the component's secrets sourced as environment variables.
[no-cd]
exec-env comp *args:
    nu "{{nu_script}}" exec-env "$@"
