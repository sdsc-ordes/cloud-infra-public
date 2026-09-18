# Style And Command Definitions

Distilled from the Nushell book (style guide, custom commands, scripts).

## Formatting

- One space before and after `|`; no consecutive spaces outside strings.
- Omit commas between list items (`[1 2 3]`, not `[1, 2, 3]`).
- One space after `:` in records, after commas in records/lists, and around
  block parameters (`{|elt, acc| $elt + $acc }`).
- One-line form for short pipelines/literals (< 80 chars, no nesting); otherwise
  multi-line with one pipeline stage, record pair, or list item per line.
- 4-space indentation (project `.editorconfig`); LF endings; final newline; no
  trailing whitespace; ASCII-only.

## Naming

| Element               | Style                  | Example             |
| --------------------- | ---------------------- | ------------------- |
| Commands              | kebab-case             | `fetch-user`        |
| Subcommands           | kebab-case (space-sep) | `main vm-reboot`    |
| Flags                 | kebab-case             | `--accept-new`      |
| Variables/parameters  | snake_case             | `deploy_id`         |
| Environment variables | SCREAMING_SNAKE_CASE   | `$env.SOPS_AGE_KEY` |

Prefer full concise words over abbreviations unless the acronym is well-known.

## String Interpolation Gotcha

Inside a `$"..."` string, `(...)` is a subexpression: `$"code (n)"` tries to run
the command `n`. To include a **literal** parenthesis, escape it with `\(` (and
`\)`). This bites most often when porting bash `echo` strings that contain
parentheses for humans.

```nu
let n = 7
$"code (n) here"        # ERROR: tries to run command `n`
$"code ($n) here"       # "code 7 here"  -- intended interpolation
$"decrypted \(($f)\)"   # "decrypted (path)"  -- literal parens + interpolation
```

## Typed Parameters

Always annotate types; this enables parse-time checking. Supported types include
`int`, `string`, `float`, `bool`, `list`, `record`, `path`, `directory`, `any`.

```nu
def greet [name: string] { $"Hello, ($name)" }
```

Optional positional with `?`, or a default value:

```nu
def greet [name?: string] { $"Hello, ($name | default 'you')" }
def congratulate [age: int = 18] { $"You are ($age)" }
```

Keep positional parameters to two or fewer (source/destination is the acceptable
two-arg shape). Use flags for everything else.

## Flags, Switches, Rest

```nu
def "main deploy" [
    comp: string            # component name
    --env (-e): string = "dev"  # flag with short form and default
    --force                 # boolean switch: false unless present
    ...ssh_args: string     # rest parameter, collected into a list
] { }
```

Access `--all-caps` as `$all_caps` (dashes become underscores). Switches are
`false` when absent, `true` when present.

## Input/Output Signatures

Declare the pipeline contract for extra parse-time validation and clearer help:

```nu
def increment []: int -> int { $in + 1 }
def "to-lines" []: list<string> -> string { str join "\n" }
```

Caveat: a tail `error make` counts as an output for this check, so a command
whose last branch raises (e.g. a key resolver that errors when nothing is
configured) will fail type-checking if annotated. Omit the output signature in
that case and document the return in the doc comment instead.

## Documentation

The comment immediately above `def` becomes the command description; a comment
after a parameter (same line) becomes that parameter's help. Document every
exported command in the imperative mood ("Encrypt a file", not "Encrypts").

```nu
# Encrypt a plaintext secret file in place.
def "main encrypt" [
    file: path              # the .dec.* file to encrypt
] { }
```

## Script Mechanics

- Subcommand dispatch: define `def "main <sub>" [...]` plus a bare `def main []`
  so the subcommands are reachable. `nu script.nu sub args` routes to the
  matching subcommand.
- Processing order: all `def`s are parsed first, then the body, then `main` runs
  last. Definitions need not precede their use.
- Untyped argv is parsed by apparent type; explicit annotations override that.
  Always annotate, so `nu script.nu +1` cannot surprise you.
- `def --env` lets a command persist `$env` changes to its caller. Prefer
  returning a value and scoping it with `with-env` over mutating ambient state;
  reserve `--env` for genuinely persistent shell state (e.g. `cd`).
- The final expression is the return value; no explicit `return` needed. Use
  `ignore` to discard unwanted pipeline output.
