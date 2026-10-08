# OpenStack CLI operations, driven from `just openstack::<recipe>`.
use lib/common.nu *
use sops.nu component-env

# Remove the temporary ssh security group (best-effort, idempotent). Requires
# the openstack-cli secrets in the environment (see `component-env`).
def remove-ssh-group [deploy_id: string] {
    let group = $"($deploy_id)-ssh-init"
    log info "Remove potential old security groups."

    let results = []
    let results = results | append ( do
        { ^openstack server remove security group $deploy_id $group } | complete
    )
    let results = results | append ( do
        { ^openstack security group delete $group } | complete
    )

    if ($results | any {|r| $r.exit_code != 0 }) {
        log info "Could not remove security groups (they may not exist)."
    }
}

# Close the ssh port on a server (best-effort, idempotent).
def "main close-ssh" [deploy_id: string] {
    let oscli = load-component "openstack-cli"
    with-env (component-env $oscli) { remove-ssh-group $deploy_id }
}

# Open the ssh port on a server via a temporary security group.
def "main open-ssh" [deploy_id: string] {
    let oscli = load-component "openstack-cli"
    with-env (component-env $oscli) {
        let exists = (
            ^openstack server list --name $deploy_id -f json
            | from json
            | any {|s| $s.Name == $deploy_id }
        )
        if not $exists {
            error make {msg: $"Server '($deploy_id)' does not exist."}
        }

        # Idempotent: drop any leftover group before recreating it.
        remove-ssh-group $deploy_id

        let group = $"($deploy_id)-ssh-init"
        log info "Add security groups."
        try {
            ^openstack security group create $group
            ^openstack security group rule create --protocol tcp --dst-port 22 --remote-ip "0.0.0.0/0" $group
            ^openstack server add security group $deploy_id $group
        } catch {
            error make {msg: $"Could not add security group ($group); see output above."}
        }
    }
}

# Manage OpenStack resources.
def main [] { }
