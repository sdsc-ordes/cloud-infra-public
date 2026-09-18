# Cloud deployment and VM access, driven from the root justfile.
use lib/common.nu *
use sops.nu component-env
use tofu.nu

# Resolve a component's IP: the WireGuard tunnel IP when enabled and requested,
# otherwise the public IP from deploy.yaml.
def resolve-ip [comp: record, wireguard: bool]: nothing -> string {
    if not $wireguard { return (component-ip $comp) }
    let wg_enabled = (^nix eval (nixos-attr $comp "settings.wireguard.enable") | str trim) == "true"
    if not $wg_enabled {
        log info "Wireguard is not enabled for this machine! Using normal IP."
        return (component-ip $comp)
    }
    ^just wg::tunnel-ip $comp.name | str trim
}

# Decrypt a sops-encrypted SSH key to a temp file, run `action` with its path,
# and always remove the temp file afterwards.
def with-ssh-key [sops_key: path, action: closure] {
    with-tmp {|tmp|
        ^sops decrypt $sops_key | save --raw --force $tmp
        ^chmod 600 $tmp
        do $action $tmp
    }
}

# Scan a host's ed25519 key and convert it to an age recipient, retrying until
# the host answers.
def fetch-age-key [ip: string, --max: int = 200]: nothing -> any {
    for attempt in 1..$max {
        if $attempt > 1 {
            log info $"Failed to ssh-keyscan -> convert to age key, try again. ($attempt)/($max)"
            sleep 1sec
        }
        log info $"Add SSH public key to sops config from '($ip)'."
        let scan = do { ^ssh-keyscan -q -t ed25519 $ip } | complete
        if $scan.exit_code != 0 { continue }

        let rec = (
            $scan.stdout
            | lines
            | where {|l| not ($l | str starts-with "#") }
            | parse "{host} {type} {key}"
            | get 0?
        )
        if $rec == null {
            log debug "Could not parse get ssh-keyscan output."

            continue
        }
        let ssh_key = $"($rec.type) ($rec.key)"

        let age = do {
            $ssh_key | ^ssh-to-age
        } | complete
        let age_key = $age.stdout | str trim
        if ($age.exit_code == 0) and ($age_key | is-not-empty) {
            log info $"SSH public key: ($ssh_key)"
            log info $"Age public key: ($age_key)"
            return $age_key
        } else {
            log info $"Failed to convert ssh-key with ssh-to-age: '($ssh_key)'."
        }
    }

    error make {msg: $"Could not ssh-keyscan ($ip) after ($max) attempts."}
}

# Run `action` with the ssh port temporarily open, closing it even on failure.
def with-open-ssh [deploy_id: string, action: closure] {
    ^just openstack::open-ssh $deploy_id

    try {
        do $action
    } catch {
        ^just openstack::close-ssh $deploy_id
        error make {msg: $"Deployment step failed on ($deploy_id) \(ssh closed again\); see output above."}
    }

    ^just openstack::close-ssh $deploy_id
}

# Append `state` to the deployment states and persist them in the OpenStack
# `nixos` server property under `os_env` secrets; return the new state list.
def mark-state [
    deploy_id: string
    states: list<string>
    state: string
    os_env: record
]: nothing -> list<string> {
    let states = $states | append $state
    with-env $os_env {
        ^openstack server set --property $"nixos=($states | str join '|')" $deploy_id
    }
    $states
}

# Deploy a component end-to-end.
def --wrapped "main deploy" [comp: string, ...args: string] {
    let comp = load-component $comp ...$args

    log info $"Deploying comp '($comp.name)'."
    tofu main-apply $comp

    # `tofu::apply` persists the new IP into deploy.yaml; read it from there
    # instead of another `tofu output` (which re-runs `init --reconfigure`).
    if $comp.type == "vm" {
        (main deploy-vm $comp ($comp.deploy_id)
            (component-ip $comp)
        )
    } else if $comp.type == "k8s" {
        log info $"K8s cluster '($comp.cluster)' deployed. Check flux with 'flux9s'."
    }
}

# Build the NixOS system closure.
def "main build-nixos" [comp: record] {
    let root = (root-dir)
    log info "Build NixOS."
    let attr = nixos-attr $comp "system.build.toplevel"
    ^nix build -L $attr --out-link ($comp.output_dir | path join $comp.deploy_id)
}

# Rebuild the NixOS VM with deploy-rs.
def --wrapped "main redeploy-nixos" [comp: record, ip: string, ...ssh_args: string] {
    let root = (root-dir)
    let resolved_ip = if ($ip | is-not-empty) { $ip } else { resolve-ip $comp true }
    let deploy_rs_args = $env.DEPLOY_RS_ARGS? | default ""
    log info $"Connecting to ($comp.name): root@($resolved_ip)"
    log info $"Redeploy NixOS with deploy-rs. [ args: '($deploy_rs_args)' ]"

    let key = $comp.secrets_dir | path join "ssh/root.prv.sops.bin"
    with-ssh-key $key {|tmp|
        let extra = $deploy_rs_args | split row -r '\s+' | compact --empty
        let ssh_opts = $"-i ($tmp) ($ssh_args | str join ' ')"
        let flake = $"($comp.system_dir)#($comp.name)"
        ^deploy ...$extra --ssh-opts $ssh_opts --ssh-user root --hostname $resolved_ip $flake
    }
}

# Deploy the system on an existing VM, tracking progress in an OpenStack property.
def "main deploy-vm" [comp: record, deploy_id: string, ip: string] {
    # Decrypt the openstack secrets once for all openstack calls below.
    let oscli = load-component "openstack-cli"
    let os_env = component-env $oscli

    mut state_list = (
        with-env $os_env { ^openstack server show -f json $deploy_id }
        | from json
        | get properties.nixos?
        | default ""
        | split row "|"
        | where {|s| $s | is-not-empty }
    )

    if "bootstrapped" not-in $state_list {
        log info "Bootstrap VM."
        with-open-ssh $deploy_id { main bootstrap-nixos $comp $ip }
        $state_list = (mark-state $deploy_id $state_list "bootstrapped" $os_env)
    }

    if "deployed" not-in $state_list {
        log info "Reencrypt secrets and redeploy VM."
        with-open-ssh $deploy_id {
            main re-encrypt-after-bootstrap $deploy_id $ip
            (main redeploy-nixos
                $comp
                $ip
                -o
                StrictHostKeyChecking=accept-new
            )
            main vm-reboot $comp false -o StrictHostKeyChecking=accept-new
        }
        $state_list = (mark-state $deploy_id $state_list "deployed" $os_env)
    } else {
        log info $"Nix is already deployed on '($deploy_id)' -> redeploy."
        main redeploy-nixos $comp ""
    }

    log info "Successfully deployed VM."
}

# Re-encrypt secrets with the freshly-bootstrapped machine's age key.
def "main re-encrypt-after-bootstrap" [deploy_id: string, ip: string] {
    let age_key = (fetch-age-key $ip)
    let config = (root-dir) | path join "components/secrets/config.toml"
    # The open|upsert|save round-trip preserves the rest of config.toml.
    open $config | upsert $"machines.($deploy_id).ageKey" $age_key | save -f $config
    ^just sops::re-encrypt false
    ^git -C ((root-dir) | path join "components/secrets") add .
}

# Bootstrap NixOS onto a fresh host with nixos-anywhere.
def "main bootstrap-nixos" [comp: record, host: string] {
    log info "Bootstrap NixOS."
    let root = (root-dir)
    let key = $root | path join "components/secrets/ssh/key-init.prv.sops.bin"
    with-ssh-key $key {|id_file| ^nixos-anywhere -i $id_file --flake $"($comp.system_dir)#($comp.name)" $"ubuntu@($host)" }
}

# Reboot the VM over ssh.
def --wrapped "main vm-reboot" [comp: record, wireguard: bool, ...ssh_args: string] {
    log info $"Reboot machine '($comp.name)'."
    main ssh-vm $comp root $wireguard ...$ssh_args reboot
}

# SSH into the component VM (extra args are passed to ssh).
def --wrapped "main ssh-vm" [
    comp: record
    user: string
    wireguard: bool
    ...ssh_args: string
] {
    let ip = (resolve-ip $comp $wireguard)
    let key = $comp.secrets_dir | path join $"ssh/($user).prv.sops.bin"

    log info $"Connecting to ($comp.name): ($user)@($ip)"
    if ($key | path exists) {
        with-ssh-key $key {|id_file| ^ssh -i $id_file $"($user)@($ip)" ...$ssh_args }
    } else {
        ^ssh $"($user)@($ip)" ...$ssh_args
    }
}

# Add the component's SSH key to the ssh-agent for five days.
def "main ssh-add" [comp: record, user: string, wireguard: bool] {
    let ip = (resolve-ip $comp $wireguard)
    let key = $comp.secrets_dir | path join $"ssh/($user).prv.sops.bin"
    with-ssh-key $key {|tmp|
        log info $"Adding SSH key for ONLY '($user)@($ip)'"
        ^ssh-add -h $"($user)@($ip)" -t 432000 $tmp
    }
    log info "All SSH keys in the agent:"
    ^ssh-add -L
    log info $"For code/zed remote desktop add the following:\n\nHost ($ip)\n    User ($user)\n"
}

# Cherry-pick the current branch onto the public mirror, stripping secrets.
def "main update-public-mirror" [branch: string] {
    with-tmp --dir {|tmp_dir|
        log info "Checking out to temp folder."
        ^git clone --single-branch --branch $branch https://github.com/sdsc-ordes/cloud-infra.git $tmp_dir
        cd $tmp_dir
        log info "Cherry pick onto new branch main from main-old."
        let new_commit = (^git commit-tree "main^{tree}" -m "Initial clean main branch" | str trim)
        ^git checkout -b main-new $new_commit
        rm --recursive components/secrets
        # Strip remaining sops files
        ls **/*.sops.*
        | each {|file| rm $file.name }
        ^git add .
        ^git commit --amend --no-edit
        ^git remote set-url origin https://github.com/sdsc-ordes/cloud-infra-public.git
        ^git push -f origin main-new:main
    }
}

# Deploy and access component VMs.
def main [] { }
