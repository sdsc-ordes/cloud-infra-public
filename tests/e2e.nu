# End-to-end tests against the integration-test component and its committed test key.
use std/assert
use ../tools/nu/lib/common.nu *

# Run a `just` recipe with the test age key; return the completed record.
def --wrapped run-just [...args: string]: nothing -> record {
    let key = root-dir | path join "tests/keys/test.agekey"
    do { ^env $"SOPS_AGE_KEY_FILE=($key)" just ...$args } | complete
}

# Decrypt the fixture through exec-env and expose its values to the command.
def test-exec-env [] {
    let r = (run-just sops::exec-env
        integration-test
        sh
        -c
        'echo "expected=[$TEST_SECRET] [$TEST_PLAIN] [$TEST_URL]"'
    )
    if $r.exit_code != 0 { print $r.stderr }
    assert equal $r.exit_code 0
    # export prefix and wrapping quotes stripped, '=' in values kept.
    assert ($r.stdout | str contains "expected=[hunter2] [plainvalue] [https://x?a=b]")
}

# Read the public IP from the committed test deploy.yaml.
def test-component-ip [] {
    let comp = load-component "integration-test"
    assert equal (component-ip $comp) "192.0.2.1"
}

# Run the full tofu flow offline against the provider-less integration-test.
# Apply must persist the output IP into deploy.yaml.
def test-tofu-flow [] {
    let dy = "components/integration-test/deploy.yaml"
    let before = open --raw $dy
    let r = run-just tofu::apply integration-test -auto-approve
    if $r.exit_code != 0 { print $r.stderr }
    assert equal $r.exit_code 0
    assert equal (open $dy | get ip.public) "192.0.2.1"

    let out = run-just tofu::output integration-test
    assert equal ($out.stdout | from json | get public_floating_ip.value) "192.0.2.1"

    # Leave the tree as found (apply rewrites and stages deploy.yaml).
    ^git restore --staged $dy
}

# Eval the flake through the wg::tunnel-ip recipe.
def test-nix-eval [] {
    let r = run-just wg::tunnel-ip integration-test
    if $r.exit_code != 0 { print $r.stderr }
    assert equal $r.exit_code 0
    assert equal ($r.stdout | str trim) "10.100.99.9"
}

def main [] {
    let root = root-dir
    cd $root
    if ($env.CLOUDINFRA_IN_DEVSHELL? | is-empty) {
        error make {msg: $"You are not in the nix devshell, tests aborted."}
    }

    test-exec-env
    test-component-ip

    # Offline but tool-gated cases: skip loudly outside the devshell.
    test-tofu-flow
    test-nix-eval
    log info "e2e: all tests passed."
}
