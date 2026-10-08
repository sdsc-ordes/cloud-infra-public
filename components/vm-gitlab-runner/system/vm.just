set positional-arguments
set fallback
set shell := ["bash", "-cue"]

default:
    just --list --unsorted -f "{{source_file()}}"

# Show some status on the VM.
[group('general')]
status: check-on-vm
   ./scripts/status.sh

# Monitor all systemd services. (press `p` for sorting by paths)
[group('general')]
monitor: check-on-vm
    systemd-cgtop

# Show the history of the NixOS on the machine.
[group('general')]
history: check-on-vm
    #!/usr/bin/env bash
    set -eu -o pipefail
    echo "History in 'system' profile:"
    nix profile history --profile /nix/var/nix/profiles/system

# Clean the VMs nix store (not the same as the jobs /nix/store !)
[group('non-destructive')]
gc: check-on-vm
    echo "Remove all generations older than 7 days"
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d

    echo "Garbage collect all unused nix store entries"
    sudo nix store gc --debug

# Prune stuff which lets the runner continue running, also does not kill jobs.
[group('non-destructive')]
podman-gc: check-on-vm
    just -f "{{source_file()}}" podman-gc-images
    just -f "{{source_file()}}" podman-gc-volumes
    just -f "{{source_file()}}" podman-gc-containers


# Stops service and flushes all images/volumes (inclusive daemon volumes) to free up space to reboot after and recreate everything.
[group('destructive')]
podman-flush-all: check-on-vm
    #!/usr/bin/env bash
    set -eu -o pipefail

    just -f "{{source_file()}}" podman-flush-job-images

    echo "Delete volumes."
    podman volume rm -f \
        nix-daemon-store \
        nix-daemon-db \
        nix-daemon-socket \
        podman-cache

    just -f "{{source_file()}}" podman-gc-volumes -f

    echo "Reboot now to recreate the volumes/service/runner."

# Stops service and flushes all job images for reboot and recreat by systemd.
[group('destructive')]
podman-flush-job-images *args: check-on-vm
    #!/usr/bin/env bash
    set -eu -o pipefail
    just -f "{{source_file()}}" systemctl-gitlab-runner-service stop || true
    just -f "{{source_file()}}" systemctl-podman-services stop || true

    echo "Remove all containers/images."
    podman container rm -f --all || true
    podman image rm -f --all || true

# Remove all containers (but not systemd spawnd containers: nix-daemon-container).
[group('non-destructive')]
podman-gc-containers *args: check-on-vm
    echo "Remove all containers (except nix-daemon-container)"
    podman --log-level debug \
        container rm --filter "label!=PODMAN_SYSTEMD_UNIT" \
        "$@"

# Remove podman images (but only ones with no label `no-prune`)
[group('non-destructive')]
podman-gc-images *args: check-on-vm
     podman --log-level debug image prune --filter "label!=no-prune" \
        "$@"

# Remove all volumes (but not nix-daemon-* volumes)
[group('non-destructive')]
podman-gc-volumes *args: check-on-vm
    ./scripts/remove-volumes.sh "$@"

# Run a GitlabCI container similar to GitlabCI runs it (mount `dir` in `image`).
[group('non-destructive')]
run-job-container dir="." image="local/alpine" user="root" script="script.sh" *args:
    #!/usr/bin/env bash
    function cleanup() { rm "$tmp_file" || true; }
    trap cleanup EXIT

    tmp_file=$(mktemp)
    args=("${@:4}")

    cmd=(
        podman run --rm -it
        --volumes-from 'nix-daemon-container'
        -v 'gitlab-runner-scratch:/scratch'
        -v 'gitlab-runner-scratch-user:/scratch-user'
        -v "podman-daemon-socket:/run/podman"
        -v "$(cd "{{dir}}" && pwd):/workspace"
        -w /workspace
    )

    run="export CI_PIPELINE_ID=123456 && gitlab-runner-pre-build-script"

    if [ "{{user}}" != "root" ]; then
        cmd+=(-e "CONTAINER_USERSPEC={{user}}:{{user}}")
        run="$run && bash"
    else
        cmd+=(-v "$tmp_file:/tmp_file.sh")

        if [ -f "$script" ]; then
            echo "Mouting 'script.sh' to execute."
            cmd+=(-v "$script:/script.sh")
            run="$run && bash /script.sh"
        else
            run="$run && bash"
        fi
    fi

    cmd+=(
         "{{image}}"
         "bash" -c "$run"
     )

    echo "Running command in Gitlab container"
    printf "'%s' " "${cmd[@]}"
    echo

    "${cmd[@]}" "${args[@]}"

# Run a systemctl command on the gitlab-runner service.
[group('systemctl')]
systemctl-gitlab-runner-service *args:
    systemctl "$@" gitlab-runner.service

# Run a systemctl command on all podman services.
[group('systemctl')]
systemctl-podman-services *args:
    systemctl "$@" \
        podman-nix-container.service \
        podman-alpine-container.service \
        podman-ubuntu-container.service \
        podman-nix-daemon-container.service \
        podman-podman-daemon-container.service

# Clean logs.
[group('non-destructive')]
clean-logs: check-on-vm
    journalctl --vacuume-time=1s


# Show the Gitlab Runner log.
[group('log')]
runner-log: check-on-vm
    journalctl -f -u gitlab-runner.service

[private]
check-on-vm:
    #!/usr/bin/env bash
    set -eu -o pipefail
    [ "$(hostname)" = "vm-gitlab-runner" ] || {
        echo "ERROR: You do not seem to be logged in on the VM."
        exit 1
    }
