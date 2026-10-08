# Run OpenTofu/Terraform operations, driven from `just tofu::<recipe>`.
use lib/common.nu *
use sops.nu component-env

# Run tofu assuming cwd is the component's infra dir
# and the component's secrets are loaded in the environment.
def --wrapped run-tofu [comp: record, ...rest: string] {
    mut vars = ["--var-file" $comp.terraform.vars_file]

    let l = $comp.terraform.vars | transpose key value | reduce --fold [] {
        |it, acc| $acc | append ["--var" $"($it.key)=($it.value)"]
    }

    let vars = $vars | append $l

    ^tofu ...$rest ...$vars
}

# Change to the component's infra directory.
def --env enter-infra-dir [comp: record] {
    cd $comp.infra_dir
}

def main-run [comp: record, ...rest: string] {
    enter-infra-dir $comp
    with-env (component-env $comp) { run-tofu $comp ...$rest }
}

# Apply infrastructure changes, then persist the new public IP into deploy.yaml.
# Secrets are decrypted once for the whole init/apply/output sequence.
export def main-apply [comp: record, ...rest: string] {
    enter-infra-dir $comp
    let ip = with-env (component-env $comp) {
        run-tofu $comp init --reconfigure
        run-tofu $comp apply ...$rest
        run-tofu $comp output --json | from json | get public_floating_ip.value
    }

    open $comp.comp_file | upsert ip.public $ip | save -f $comp.comp_file
    ^git -C $comp.root_dir add $comp.comp_file
}

# Run a tofu command for a component, with vars and secrets loaded via sops.
def --wrapped "main run" [comp: string, ...rest: string] {
    let comp = load-component $comp ...$rest
    main-run $comp ...$comp.tool_args
}
# Apply infrastructure changes, then persist the new public IP into deploy.yaml.
# Secrets are decrypted once for the whole init/apply/output sequence.
def --wrapped "main apply" [comp: string, ...rest: string] {
    let comp = load-component $comp ...$rest
    main-apply $comp ...$comp.tool_args
}

# Manage infrastructure with OpenTofu.
def main [] { }
