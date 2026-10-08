#!/usr/bin/env bash
set -eu -o pipefail

echo "===================="
echo "Disk Space:"
df -H | grep -E "/root|overlay"
echo "===================="

echo "===================="
echo "Podman Images [no-prune]"
podman images --filter "label=no-prune"
echo "Other images count: $(podman images --filter 'label!=no-prune' | wc -l)"
echo "===================="

echo "===================="
echo "Volumes (nix-daemon-container):"
podman container inspect -f "{{ json .Mounts }}" nix-daemon-container |
    jq '.[] | select(.Type == "volume") | .Name, .Destination'

echo "Volume Sizes (nix-daemon-container)"
podman container inspect -f "{{ json .Mounts }}" nix-daemon-container |
    jq '.[] | select(.Type == "volume") | .Source' | xargs -I {} du -sh {}
echo "===================="

echo "===================="
echo "Memory Usage:"
free -h
echo "===================="

echo "===================="
echo "Gitlab Runner Config"
cat /var/lib/gitlab-runner/.gitlab-runner/config.toml
echo "===================="
