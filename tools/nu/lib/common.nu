# Shared helpers for the cloud-infra nushell tooling.
#
# Importing this module brings nushell's built-in `std log` commands into scope
# (`log info`, `log warning`, ...), filtered by `NU_LOG_LEVEL` (default INFO):
#   use lib/common.nu *

use std/log
use std/iter

# Defaults for `std log`. The level and date defaults are required on
# nushell <= 0.103 (the devshell version), whose std/log errors without them;
# newer std versions only need the format override (drops the date prefix).
export-env {
    $env.NU_LOG_LEVEL = ($env.NU_LOG_LEVEL? | default "INFO")
    $env.NU_LOG_FORMAT = ($env.NU_LOG_FORMAT? | default "🌻 %ANSI_START%%LEVEL%%ANSI_STOP% | %MSG%")
    $env.NU_LOG_DATE_FORMAT = ($env.NU_LOG_DATE_FORMAT? | default "%Y-%m-%dT%H:%M:%S%.3f")
}

export def "log error" [message: string] {
    log custom $message $env.NU_LOG_FORMAT (log log-level | get ERROR) --ansi (ansi red_reverse) --level-prefix "ERROR"
}

export def "log warning" [message: string] {
    log custom $message $env.NU_LOG_FORMAT (log log-level | get WARNING) --ansi (ansi yellow_reverse) --level-prefix "WARN"
}

export def "log info" [message: string] {
    log custom $message $env.NU_LOG_FORMAT (log log-level | get INFO) --ansi (ansi cyan_reverse) --level-prefix "INFO"
}

export def "log debug" [message: string] {
    log custom $message $env.NU_LOG_FORMAT (log log-level | get DEBUG) --ansi (ansi magenta_reverse) --level-prefix "DEBUG"
}

# Absolute path to the repository root.
export def root-dir []: nothing -> string {
    ^git rev-parse --show-toplevel | str trim
}

export def load-k8s-settings [comp: record, ...args: string]: nothing -> record {
    mut parsed_idx = []

    # Parse cluster argument.
    mut cluster = ""
    let idx = $args | iter find-index {|x| $x == "--cluster" }
    if ($idx | is-not-empty) {
        $cluster = $args | get -o ($idx + 1)
        $parsed_idx = $parsed_idx | append [
            $idx
            ($idx + 1)
        ]
    }

    if ($cluster | is-empty) {
        error make {msg: "cluster name with `--cluster` must be given"}
    }

    let tool_args = $args
    | enumerate
    | where {|it| $it.index not-in $parsed_idx}
    | get item
    let deploy_id = $"($comp.name)-($cluster)"
    let infra_dir = $comp.root_dir | path join "infra" "deployments" $cluster
    let tfvars_file = $infra_dir | path join "values.tfvars"
    let kubeconfig = $env.HOME | path join $".config/kube/($cluster)"

    return {
        deploy_id: $deploy_id
        infra_dir: $infra_dir
        cluster: $cluster
        kubeconfig: $kubeconfig
        terraform: {
            vars_file: $tfvars_file
            vars: {deploy_id: $deploy_id, cluster_name: $cluster, kubeconfig: $kubeconfig}
        }
        tool_args: $tool_args
    }
}

export def load-vm-settings [comp: record, ...args: string]: nothing -> record {
    mut parsed_idx = []

    # Parse env argument.
    mut environ = "dev"
    let idx = $args | iter find-index {|x| $x == "--env" }
    if ($idx | is-not-empty) {
        $environ = get -o ($idx + 1)
        $parsed_idx = $parsed_idx | append [
            $idx
            ($idx + 1)
        ]
    }

    let tool_args = $args
    | enumerate
    | where {|it| $it.index not-in $parsed_idx}
    | get item
    let deploy_id = $"($comp.name)-($environ)"
    let infra_dir = $comp.root_dir | path join "infra"
    let tfvars_file = $infra_dir | path join "values.tfvars"

    return {
        deploy_id: $deploy_id
        infra_dir: $infra_dir
        system_dir: ($comp.root_dir | path join "system")
        environment: $environ
        tool_args: $tool_args
        terraform: {
            vars_file: $tfvars_file
            vars: {deploy_id: $deploy_id}
        }
    }
}

# Load component configuration from deploy.yaml
# NOTE: `--cluster` should not be specified at this level, but currently there is not
# way to take variadic arguments and forward them into `load_k8s_settings` which again
# parses flags correctly.
export def load-component [comp: string, ...args]: nothing -> record {
    let file = root-dir | path join "components" $comp "deploy.yaml"
    log info $"Load file: ($file)"
    mut cfg = open $file

    $cfg.name = $comp
    $cfg.root_dir = root-dir | path join "components" $cfg.name
    $cfg.comp_file = $file
    $cfg.output_dir = root-dir | path join ".output" $cfg.name
    $cfg.secrets_dir = root-dir | path join "components" "secrets" $cfg.name

    let type = $cfg.type
    let setts = match $type {
        "k8s" => { load-k8s-settings $cfg ...$args }
        "vm" => { load-vm-settings $cfg ...$args }
        "openstack-cli" => { {} }
        _ => {error make {msg: $"component type '($type)' not supported"}}
    }

    $cfg = $cfg | merge deep $setts

    log info $"Loaded component with\n($cfg | table --expand)"

    $cfg
}

# The public IP persisted in a component's deploy.yaml.
export def component-ip [comp: record]: nothing -> string {
    $comp.ip.public
}

# The flake attribute path for a component's NixOS configuration option.
export def nixos-attr [comp: record, option: string]: nothing -> string {
    $"($comp.system_dir)#nixosConfigurations.($comp.name).config.($option)"
}

# Run `action` with a fresh temp file (or directory with --dir), removing it
# afterwards even when the action fails.
export def with-tmp [action: closure, --dir] {
    let tmp = if $dir { mktemp --directory -t } else { mktemp -t }
    try {
        do $action $tmp
    } catch {
        rm --recursive --force $tmp
        error make {msg: $"Action failed \(cleaned up temp path ($tmp)\); see output above."}
    }
    rm --recursive --force $tmp
}
