# Repo Integration

How Nushell fits into this repository's `just` + `nix` + `sops` tooling.

## Module Layout

```
tools/nu/
├── lib/
│   └── common.nu   # single shared lib: re-exports std log, root-dir
├── sops.nu         # `main <sub>` for the longer/shared/argv recipes
├── tofu.nu
├── openstack.nu
├── wireguard.nu
├── nix.nu
└── deploy.nu       # root-level cloud recipes
```

Domain scripts import the shared lib at the top:

```nu
use lib/common.nu *     # brings in root-dir and log*
```

Relative `use` paths resolve relative to the **importing file**, so this works
no matter the current directory.

### export-env Caveat

`std log` reads `NU_LOG_LEVEL`, `NU_LOG_FORMAT`, `NU_LOG_DATE_FORMAT` directly.
Nushell's interactive startup sets them, but `nu <script>.nu` does not, so
`common.nu` sets defaults in an `export-env` block. Note that `export use` does
**not** carry an `export-env` block to re-exporters: a new module that
re-exports `common.nu` and needs those defaults at its own entry point must
declare its own `export-env`.

## The `just` Wrapper Pattern

`just` stays the discoverable entry point (`just --list`, `[confirm]`,
`[group]`, `[private]`, `dotenv-load`). Each recipe body is one linewise call
that forwards quoted argv to the Nushell subcommand:

```just
# Encrypt a secrets file.
[no-cd]
encrypt file:
    nu "{{root_dir}}/tools/nu/sops.nu" encrypt "{{file}}"
```

- Quote every `{{interpolation}}` — values reach Nushell as argv, not code.
- Declare argument defaults only in the `just` recipe (the public contract);
  keep the `main` parameters required so the two layers cannot drift.
- Keep `just` attributes (`[private]`, `[confirm("...")]`, `[no-cd]`) on the
  wrapper; do not reimplement them in Nushell.
- Preserve recipe and module names so `just sops::encrypt` keeps working.
- Keep the `[private] default:` recipe that runs `just --list <module>`.

### Inline vs module

Use the wrapper-to-module pattern above when a recipe is long, shares helpers
with other recipes, or takes variadic/flag arguments (those need argv plus
`def --wrapped` so flags are not parsed by the subcommand). For a **short,
standalone** recipe, skip the extra file and write the nushell inline as a
`#!/usr/bin/env nu` shebang recipe, importing the lib by absolute path:

```just
# Decrypt an encrypted file to stdout.
[no-cd]
decrypt file:
    #!/usr/bin/env nu
    use "{{root_dir}}/tools/nu/lib/common.nu" *
    let f = ("{{file}}" | path expand)
    log info $"Decrypting ($f)..."
    ^sops decrypt $f
```

Inline trade-offs to respect:

- Parameters arrive via `just` interpolation (`{{file}}`), which is spliced into
  the nushell **source** — quote each interpolation and keep inputs trusted.
  Prefer the wrapper (argv) for variadic/flag args or values with odd
  characters.
- `use` paths must be absolute (the body runs from a temp file), so interpolate
  `{{root_dir}}`.
- A script with no `def main` ignores the extra argv `just` passes under
  `set positional-arguments`, so inline recipes are safe with that setting.

## Structured-Data Idioms

Replace text parsing with native parsing and selectors. Nushell reads JSON, YAML
and TOML directly with `open`, and edits records with `upsert`.

| Old (bash + jq/yq/toml/grep)                     | New (nushell)                           |
| ------------------------------------------------ | --------------------------------------- | -------------------- | ----------------------------- | -------------------- | ----- | --- | ---------------------- |
| `out=$(...); jq -er '.public_floating_ip.value'` | `...                                    | from json            | get public_floating_ip.value` |
| `yq -re ".ip.public" deploy.yaml`                | `open deploy.yaml                       | get ip.public`       |
| `yq -i ".ip.public=\"$ip\"" deploy.yaml`         | `open deploy.yaml                       | upsert ip.public $ip | save -f deploy.yaml`          |
| `toml set config.toml k "$v"                     | sponge config.toml`                     | `open config.toml    | upsert k $v                   | save -f config.toml` |
| `echo "$s"                                       | grep -q bootstrapped`                   | `$s                  | split row "                   | "                    | any { | x   | $x == "bootstrapped"}` |
| `readarray -t f < <(fd -g '**/*.sops*')`         | `glob **/*.sops*` (or `fd` via `^fd ... | lines`)              |
| `for f in "${files[@]}"; do sops ... "$f"; done` | `for f in $files { ^sops ... $f }`      |

`open` infers the format from the extension; force one with `--raw`/`from toml`
when needed. Use `save -f` to overwrite. Prefer reading a value into a typed
variable over interpolating shell command substitutions.

Note `glob` does **not** respect `.gitignore` (unlike `fd`'s default). Choose
intentionally: `glob` matches `fd -u` (unrestricted); to honour ignore files,
call `^fd ... | lines`.

## Secrets

sops resolves age keys natively, reading `SOPS_AGE_KEY`, `SOPS_AGE_KEY_FILE`
(including a passphrase-encrypted key file, which it decrypts by prompting) and
the default `~/.config/sops/age/keys.txt` on its own. Do not reimplement this:
just call `^sops ...` and let it find the key (the path comes from `.env` via
the recipe's `dotenv-load`). There is no key-loading helper.

Never read decrypted secret values into logs, and never write secret files
outside the repository.

## Validation

Run after every change (cheapest verification first):

```bash
nu -c 'nu-check --debug tools/nu/<file>.nu'                   # scripts
nu -c 'nu-check --debug --as-module tools/nu/lib/<file>.nu'   # modules
just format                                                   # treefmt
```

`nu-check` returns `true`/`false`; a parse failure must be treated as a build
failure. The repository wires `nu-check` into the `prek` pre-commit hooks so it
runs on every commit.

## Devshell

`nushell` is provided by the dev shell (`tools/nix/flake.nix`, `basicsPkgs`).
Enter it with `just develop`; do not rely on a system-wide `nu`.

Wrapper derivations called from nushell must carry a shebang: define them with
`pkgs.writeShellScriptBin`, not `pkgs.writeScriptBin`. Nushell's `^cmd` execve's
the target directly and fails with `Exec format error (os error 8)` on a
shebang-less script, whereas bash silently retries it via `/bin/sh` — so a
`writeScriptBin` wrapper appears to work until the first nushell caller.
