#!/usr/bin/env bash
# Publish one vendored chart to ghcr. --check-only validates that the
# computed version is not already published (used as a PR gate).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

REGISTRY_HOST="ghcr.io/tenxprotocols/helm-trusted-charts"

chart=""
check_only=false
for arg in "$@"; do
  case "$arg" in
    --check-only) check_only=true ;;
    -*) echo "usage: publish.sh <chart> [--check-only]" >&2; exit 2 ;;
    *) chart="$arg" ;;
  esac
done
if [[ -z "$chart" ]]; then
  echo "usage: publish.sh <chart> [--check-only]" >&2
  exit 2
fi

version=$(compute_publish_version "$chart")
chart_name=$(yq '.name' "charts/$chart/Chart.yaml")
tag="${version//+/_}"

if oras repo tags "$REGISTRY_HOST/$chart_name" 2>/dev/null | grep -qx "$tag"; then
  if $check_only; then
    echo "error: $chart $version (tag $tag) is already published —" \
      "bump the revision in publish.yml or wait for a new upstream version" >&2
    exit 1
  fi
  echo "skip: $chart $version already published"
  exit 0
fi

if $check_only; then
  echo "ok: would publish $chart $version"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

helm package "charts/$chart" --version "$version" -d "$tmp" > /dev/null
push_out=$(helm push "$tmp/${chart_name}-${version}.tgz" "oci://$REGISTRY_HOST" 2>&1) \
  || { echo "$push_out" >&2; echo "error: helm push failed for $chart $version" >&2; exit 1; }
echo "$push_out"

if [[ "${CI:-}" == "true" ]]; then
  digest=$(grep -o 'sha256:[0-9a-f]*' <<< "$push_out" | head -1)
  cosign sign --yes "$REGISTRY_HOST/$chart_name@$digest"
fi

echo "published: $chart $version"
