# Unit tests for the pure nushell helpers, run via `just test`.
use std/assert
use ../tools/nu/sops.nu parse-dotenv

def main [] {

    # Blanks and comments are skipped; `export ` and wrapping quotes stripped.
    let parsed = (
        "\n# a comment\nexport FOO=\"bar\"\n  BAZ = qux \n"
        | parse-dotenv
    )
    assert equal $parsed {FOO: "bar", BAZ: "qux"}

    # Duplicate keys: the last value wins (dotenv semantics).
    assert equal ("A=1\nA=2" | parse-dotenv) {A: "2"}

    # Values may contain '='; only the first one splits key from value.
    assert equal ("URL=https://x?a=b" | parse-dotenv) {URL: "https://x?a=b"}

    log info "unit: all tests passed."
}
