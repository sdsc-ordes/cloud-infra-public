# Manage WireGuard tunnels and keys, driven from `just wg::<recipe>`.
use lib/common.nu *

# The `[users.<user>]` record from the secrets config.
def user-config [user: string] {
    let config = root-dir | path join "components/secrets/config.toml"
    open $config | get users | get $user
}

# Generate a WireGuard keypair: an age-encrypted private key and a public key.
def "main genkey" [
    user: string    # secrets-config user allowed to decrypt the private key
    file: path      # output base path; writes <file>.age and <file>.pub
] {
    let agekey = user-config $user | get ageKey?
    if ($agekey | is-empty) {
        error make {msg: $"Age key for user '($user)' not found."}
    }
    let key = (^wg genkey | str trim)
    mkdir ($file | path dirname)
    $key | ^age -r $agekey | save --raw $"($file).age"
    $key | ^wg pubkey | save --raw $"($file).pub"
}

# Bring a component's WireGuard tunnel up/down (args forwarded to wg-quick).
def --wrapped "main quick" [comp: string, ...rest] {
    let comp = load-component $comp ...$rest
    let user = $env.WIREGUARD_USER? | default ""
    if ($user | is-empty) {
        error make {msg: "The env var 'WIREGUARD_USER' is not defined."}
    }
    let wg_key = $env.WIREGUARD_PRIVATE_KEY_FILE? | default ""
    if ($wg_key | is-empty) {
        error make {msg: "The env var 'WIREGUARD_PRIVATE_KEY_FILE' is not defined."}
    }

    let root = (root-dir)
    let ip_index = user-config $user | get wireguard.ipIndex
    let server_ip = (component-ip $comp)
    log info $"WireGuard server IP for '($comp.name)': '($server_ip)'"
    let server_pubkey = (
        open ($root | path join "components/secrets/wireguard/server.pub")
        | str trim
    )

    let age_key = $env.SOPS_AGE_KEY? | default ""
    let client_privkey = if ($age_key | is-not-empty) {
        $age_key | ^age -d -i - $wg_key | str trim
    } else {
        let age_id_file = $env.SOPS_AGE_KEY_FILE? | default ""
        if not ($age_id_file | path exists) {
            error make {msg: "Set 'SOPS_AGE_KEY_FILE' to your age identity file, or 'SOPS_AGE_KEY' to the key contents."}
        }
        ^age -d -i $age_id_file $wg_key | str trim
    }

    log info "Rendering wireguard config."
    let attr = nixos-attr $comp "settings.wireguard.showDefaultConfig"
    let apply = $"f: f {
        clientPrivKey = \"($client_privkey)\";
        clientIdx = ($ip_index);
        serverPubKey = \"($server_pubkey)\";
        serverIP = \"($server_ip)\";
    }"
    let wg_rendered_config = (^nix eval --raw $attr --apply $apply)

    # Interface names must be < 15 bytes.
    log info "Running 'wg-quick'..."
    let iface = $comp.name | str substring 0..<15
    with-tmp --dir {|tmp_dir|
        let config = $tmp_dir | path join $"($iface).conf"
        $wg_rendered_config | save --raw $config
        ^chmod 600 $config
        ^wg-quick ...$comp.tool_args $config
    }
}

# Manage WireGuard tunnels and keys.
def main [] { }
