# Statically check all nushell files in the repository (`just check`).
use ../nu/lib/common.nu *

def main [] {
    let root = root-dir
    cd $root
    # ide-check reports parse errors as data (nu-check --debug raises a
    # span-less error on the first bad file instead).
    let bad = glob "**/*.nu" | where {|f|
        let errors = (
            ^nu --ide-check 9 $f | lines | each { from json }
            | where type? == "diagnostic" and severity? == "Error"
        )
        for e in $errors {
            # Spans are byte offsets; fine to index with, the repo is ASCII-only.
            let line = open --raw $f | str substring 0..<$e.span.start | split row "\n" | length
            print $"($f):($line): ($e.message)"
        }
        $errors | is-not-empty
    }
    if ($bad | is-not-empty) {
        error make {msg: $"nu-check failed for: ($bad | str join ', ')"}
    }
}
