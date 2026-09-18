# Manage SOPS secrets, driven from `just sops::<recipe>`.
use lib/common.nu *

const ENC_SUFFIX = ".sops"
const DEC_SUFFIX = ".dec"

# Absolute paths of the secret files a component needs, from its deploy.yaml.
def component-secrets [comp: record]: nothing -> list<string> {
    $comp.env | each {|rel| root-dir | path join "components" "secrets" $rel }
}

# Parse `KEY=value` lines (sops dotenv output) into an environment record,
# skipping blanks and comments and stripping an optional `export ` and wrapping
# double quotes. Exported for the unit tests in tests/unit.nu.
export def parse-dotenv []: string -> record {
    $in
    | lines
    | str trim
    | where {|l| ($l | is-not-empty) and (not ($l | str starts-with "#")) }
    | parse --regex '^(?:export\s+)?(?<key>[^=]+)=(?<value>.*)$'
    | each {|row| {
        key: ($row.key | str trim)
        value: ($row.value | str trim | str trim --char '"')
    } }
    | reduce --fold {} {|row, acc| $acc | upsert $row.key $row.value }
}

# Encrypt a '*.dec.*' file to its '*.sops.*' counterpart, removing the source.
def "main encrypt" [file: path] {
    let f = $file | path expand
    log info $"Encrypting ($f)..."
    if not ($f | path exists) {
        error make {msg: $"File ($f) does not exist."}
    }

    let base = $f | path basename
    if not ($base | str contains $DEC_SUFFIX) {
        error make {msg: $"Can only encrypt files with a '($DEC_SUFFIX)' extension."}
    }
    let enc_name = $base | str replace $DEC_SUFFIX $ENC_SUFFIX
    let enc_file = $f | path dirname | path join $enc_name

    let status = do { ^sops filestatus $f } | complete
    let already_encrypted = (
        ($status.exit_code == 0)
        and (($status.stdout | from json | get encrypted?) == true)
    )
    if $already_encrypted {
        error make {msg: $"File is already encrypted: ($f)"}
    }

    log info $"Saving to ($enc_file)."
    try {
        ^sops -e $f | save --raw $enc_file
    } catch {
        if ($enc_file | path exists) { rm --force $enc_file }
        error make {msg: $"sops encryption failed for ($f)."}
    }
    rm $f
    log info "Done."
}

# Encrypt every '*.dec*' secret file in the repository.
def "main encrypt-all" [] {
    let root = root-dir
    cd $root
    for f in (glob $"**/*($DEC_SUFFIX)*") {
        main encrypt $f
    }
}

# Re-encrypt all secrets based on secrets.yaml, optionally rotating the data key.
def "main re-encrypt" [rotate: bool] {
    log info "Re-encrypting all secret files."
    let root = root-dir
    cd $root
    for f in (glob $"**/*($ENC_SUFFIX)*") {
        ^sops updatekeys -y $f
        if $rotate { ^sops rotate -i $f }
    }
}

# Decrypt a component's secret files into an environment record.
export def component-env [comp: record]: nothing -> record {
    component-secrets $comp
    | reduce --fold {} {|f, acc|
        $acc | merge (^sops decrypt $f | parse-dotenv)
    }
}

# Run a command with the component's secrets loaded as environment variables.
def --wrapped "main exec-env" [comp: string, ...rest] {
    let comp = load-component $comp ...$rest
    let rest = $comp.tool_args

    if ($rest | is-empty) { error make {msg: "exec-env requires a command to run."} }
    let cmd = $rest | first
    with-env (component-env $comp) { ^$cmd ...($rest | skip 1) }
}

# Manage secrets with SOPS and age.
def main [] { }
