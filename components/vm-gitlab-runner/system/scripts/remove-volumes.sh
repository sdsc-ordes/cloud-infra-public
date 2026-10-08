#!/usr/bin/env bash
set -eu -o pipefail

FORCE=false
[ "${1:-}" = "-f" ] && FORCE=true

if podman container inspect nix-daemon-container &>/dev/null; then
    readarray -t nix_volumes < <(podman container inspect -f "{{ json .Mounts }}" nix-daemon-container |
        jq -r '.[] | select(.Type == "volume") | .Name')
else
    nix_volumes=(
        nix-daemon-store
        nix-daemon-socket
        nix-daemon-db
    )
fi

echo "===================="
echo "Nix Volumes (no delete)"
printf " - %s\n" "${nix_volumes[@]}"
echo "===================="

if podman container inspect podman-daemon-container &>/dev/null; then
    readarray -t podman_volumes < <(podman container inspect -f "{{ json .Mounts }}" podman-daemon-container |
        jq -r '.[] | select(.Type == "volume") | .Name')
else
    podman_volumes=(
        podman-shared
        podman-daemon-socket
        podman-cache
    )
fi

echo "===================="
echo "Podman Volumes (no delete)"
printf " - %s\n" "${podman_volumes[@]}"
echo "===================="

# Merge nix + podman volumes into a single list
used_volumes=("${nix_volumes[@]}" "${podman_volumes[@]}")

# Get all volumes (names only)
readarray -t all_volumes < <(podman volume ls --filter='label!=no-prune' --format "{{.Name}}")

# Filter: only volumes not in "used_volumes"
# Show files in the first list, that are not in the second list.
readarray -t delete_candidates < <(
    comm -23 \
        <(printf '%s\n' "${all_volumes[@]}" | sort) \
        <(printf '%s\n' "${used_volumes[@]}" | sort)
)

if [ "${#delete_candidates[@]}" -eq 0 ]; then
    echo "No volumes to remove."
    exit 0
fi

echo "===================="
echo "Removing Volumes"
printf " - %s\n" "${delete_candidates[@]}"
echo "===================="

if [ "${FORCE:-false}" = "false" ]; then
    echo -n "Do you want to continue? [y/N]"
    read -r remove

    if [ "$remove" != "y" ]; then
        exit 0
    fi
fi

echo "Deleting volumes now ..."
podman volume rm -f "${delete_candidates[@]}" || {
    echo "Could not delete all volumes."
    exit 1
}
