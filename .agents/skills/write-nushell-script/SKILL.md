---
name: write-nushell-script
description: >-
  Defines conventions to write and edit Nushell (.nu) scripts and modules.
  Triggers when creating or editing any .nu file, or editing Nushell code. Skip
  when only running existing scripts
---

# Write Nushell Script

## When To Use

Apply this skill whenever creating or modifying a `.nu` file, porting bash or
shebang `just` recipes to Nushell, or adding a Nushell script behind a `just`
recipe. For invoking existing recipes use `run-just`; for editing the `just`
wrappers themselves use `edit-justfile`.

References (load just-in-time):

- `references/style-and-commands.md`: formatting, naming, typed parameters,
  flags, input/output signatures, doc comments.
- `references/errors-and-externals.md`: the error model, `error make`,
  `do | complete`, `try/catch`, retry and cleanup patterns, external commands.
- `references/repo-integration.md`: module layout, the shared `lib`, the `just`
  wrapper pattern, validation, and structured-data idioms that replace
  `jq`/`yq`/`sed`/`grep`.

## Core Principles

These map the SDSC `AGENTS.md` values onto Nushell:

- **Typed over stringly-typed.** Annotate every parameter (`comp: string`,
  `wireguard: bool`). The parser rejects bad input before the script runs, which
  is the cheapest verification.
- **Typed errors, not abrupt exit.** Model failures as values or raised errors
  the caller can catch with `error make`. Never call `exit`.
- **Propagate with context.** Wrap a failing step's error with what was being
  attempted; preserve the cause.
- **Structured data over text.** Use native `from json` / `open` / `get` /
  `upsert` instead of piping through `jq`, `yq`, `sed`, or `grep`.
- **Explicit and self-documenting.** Imports at the top, concise doc comments on
  every exported command, ASCII-only, no hidden global state.

## Step 1: Place The Script And Choose The Entry Shape

Put domain logic in `tools/nu/<domain>.nu`; shared helpers live in
`tools/nu/lib/`. A script invoked as a CLI uses subcommand dispatch so argv maps
straight onto typed parameters:

```nu
use lib/common.nu *

# Encrypt a plaintext secret file.
def "main encrypt" [file: path] { ... }

# Decrypt an encrypted secret file to stdout.
def "main decrypt" [file: path] { ... }

# Required for `main <sub>` dispatch; intentionally empty.
def main [] { }
```

Run it with `nu tools/nu/sops.nu encrypt path/to/file`. Arguments arrive as real
argv (safely quoted), never spliced into code. See
`references/repo-integration.md` for the matching thin `just` wrapper.

## Step 2: Define Typed Commands

Annotate parameters and document them inline. Keep positional parameters to two
or fewer; use flags for the rest. Commands are `kebab-case`, parameters
`snake_case`. Details and the full signature syntax are in
`references/style-and-commands.md`.

```nu
# Reboot a component VM.
def "main vm-reboot" [
    comp: string            # component name, e.g. vm-ordes-main
    --wireguard             # connect over the WireGuard tunnel
    ...ssh_args: string     # extra args forwarded to ssh
] { ... }
```

## Step 3: Log And Fail With The Shared Lib

`use lib/common.nu *` brings in `root-dir` and nushell's built-in `log`
commands. Use leveled logging (filtered by `NU_LOG_LEVEL`, default `INFO`) and
`error make` for unrecoverable conditions:

```nu
use lib/common.nu *

log info $"Deploying ($comp)."
log debug $"Resolved ip ($ip)."
if not ($cfg | path exists) { error make {msg: $"Missing config ($cfg)."} }
```

`error make` raises a typed, catchable error (it does not `exit`), so callers
can wrap it and the source location is preserved. Tune verbosity with
`NU_LOG_LEVEL=DEBUG just <recipe>`.

## Step 4: Handle Errors And External Commands

External commands run with the `^` prefix and **fail-fast**: a non-zero exit
aborts the script. To tolerate an expected failure (retry loops, best-effort
cleanup), capture it explicitly:

```nu
let r = (do { ^ssh-keyscan -t ed25519 $ip } | complete)
if $r.exit_code != 0 { ... }            # decide, do not silently ignore

try { ^just openstack::close-ssh $id } catch { log warning "cleanup skipped" }
```

Spread argument lists into externals with `...$args`. Full patterns — the error
record shape, `error make`, retry and cleanup idioms — are in
`references/errors-and-externals.md`.

## Step 5: Prefer Structured Data Over Text Parsing

Replace text munging with native parsing. A few canonical conversions (full
table in `references/repo-integration.md`):

| Old (bash)                                 | New (nushell)                       |
| ------------------------------------------ | ----------------------------------- | -------------------- | -------------------- | ----------------------------- | ----- | --- | ---------------------- |
| `...                                       | jq -er '.public_floating_ip.value'` | `...                 | from json            | get public_floating_ip.value` |
| `yq -i ".ip.public = \"$ip\"" deploy.yaml` | `open deploy.yaml                   | upsert ip.public $ip | save -f deploy.yaml` |
| `echo "$state"                             | grep -q bootstrapped`               | `$state              | split row "          | "                             | any { | s   | $s == "bootstrapped"}` |

## Step 6: Validate Every Change

Static-check every `.nu` file (cheapest verification; treat failure as a build
failure):

```bash
nu -c 'nu-check --debug tools/nu/<file>.nu'              # script
nu -c 'nu-check --debug --as-module tools/nu/lib/<file>.nu'  # module
```

Then run `just format`. Keep files at 4-space indentation (`.editorconfig`) and
ASCII-only.

## Operational Notes

- Relative `use` paths resolve relative to the **importing file**, not the
  working directory, so `tools/nu/sops.nu` doing `use lib/common.nu *` works
  from any CWD.
- `export use other.nu *` re-exports commands but **not** the `export-env`
  block; a module that needs env defaults must declare its own `export-env`.
- The canonical living example is `tools/nu/lib/common.nu` (the single shared
  lib module). Read it before writing a new module.
