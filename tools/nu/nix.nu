# Nix flake operations, driven from `just nix::<recipe>`.
use lib/common.nu *

# Enter the Nix dev shell `shell` and run `rest` (defaults to an interactive shell).
def --wrapped "main develop" [shell: string, ...rest] {
    let flake_dir = root-dir | path join "tools/nix"
    let sh = $env.SHELL? | default "bash"
    let cmd = if ($rest | is-empty) { ["env" $"SHELL=($sh)" $sh] } else { $rest }
    ^nix develop --accept-flake-config $"($flake_dir)#($shell)" --command ...$cmd
}

# Build a package from the flake's `packages` output into .output/package/.
def --wrapped "main package" [attrname: string, ...rest] {
    let root = (root-dir)
    let flake_dir = $root | path join "tools/nix"
    let out_dir = $root | path join ".output/package"
    mkdir $out_dir
    let out_link = $out_dir | path join $attrname
    ^nix build --accept-flake-config -L $"($flake_dir)#($attrname)" ...$rest --out-link $out_link
}

# Work with the project's Nix flake.
def main [] { }
