#!/usr/bin/env bash
# Deploy hackagon by hand, until the chart is published as an OCI artifact and
# the flux pipeline takes over.
#
# Usage: ./deploy.sh <dev|prod> <values.yaml> <realm.json> <path/to/hackagon/helm-chart> [helm args...]
#   sops decrypt values-dev.sops.yaml > /tmp/values.yaml
#   sops decrypt realm-hackagon.sops.bin > /tmp/realm.json
#   ./deploy.sh dev /tmp/values.yaml /tmp/realm.json ~/src/hackagon/helm-chart --dry-run=server
#
# The values file must carry everything else the chart needs, secrets included.
# Extra arguments are passed straight to `helm upgrade`.
set -euo pipefail

usage="usage: deploy.sh <dev|prod> <values.yaml> <realm.json> <path/to/hackagon/helm-chart> [helm args...]"
env=${1:?$usage}
values=${2:?$usage}
realm=${3:?$usage}
chart=${4:?$usage}
shift 4

case $env in
dev | prod) ;;
*)
    echo "$usage" >&2
    exit 1
    ;;
esac

for bin in helm kubectl; do
    command -v "$bin" >/dev/null || {
        echo "$bin not found" >&2
        exit 1
    }
done

chart=$(cd "$chart" && pwd)

# The chart is unpublished, so its subchart repositories must be known locally.
helm repo add --force-update bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo add --force-update helmforge https://repo.helmforge.dev >/dev/null
helm dependency build "$chart"

echo "deploying $env to namespace hackagon-$env of $(kubectl config current-context)"

# The release name stays `hackagon` in every namespace: `hackagon.fullname`
# collapses to it, and the values point at the hackagon-realm and
# hackagon-keycloak-init configmaps that the chart then generates. Helm release
# storage is namespaced, so dev and prod do not collide.
#
# The realm goes in with --set-file, which also means it wins over any realmJson
# the values file happens to carry.
helm upgrade --install hackagon "$chart" \
    --namespace "hackagon-$env" --create-namespace \
    --values "$values" \
    --set-file "realmJson=$realm" \
    --timeout 40m \
    "$@"
