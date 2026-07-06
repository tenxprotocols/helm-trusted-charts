#!/usr/bin/env bash
# Prints "<name> <current> <latest>" for each chart with a newer stable
# upstream version. Prereleases (containing '-') are ignored.
set -euo pipefail
cd "$(dirname "$0")/.."

config="${1:-.charts.yml}"
count=$(yq '.charts | length' "$config")

for i in $(seq 0 $((count - 1))); do
  name=$(yq ".charts[$i].name" "$config")
  current=$(yq ".charts[$i].version" "$config")
  url=$(yq ".charts[$i].repository.url" "$config")

  if [[ "$url" == oci://* ]]; then
    tags=$(oras repo tags "${url#oci://}/$name") \
      || { echo "error: tag lookup failed for $name at $url" >&2; exit 1; }
  else
    tags=$(curl -fsSL "$url/index.yaml" | yq ".entries.\"$name\"[].version") \
      || { echo "error: index lookup failed for $name at $url" >&2; exit 1; }
  fi
  # Only bare semver (optional v prefix) qualifies as a stable release —
  # drops prereleases AND non-semver tags like "latest" or "sha256-*",
  # and guarantees $latest is safe to splice into the update-bot's yq edit.
  latest=$(printf '%s\n' "$tags" | { grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sort -V | tail -1)

  if [[ -z "$latest" ]]; then
    echo "error: no stable versions found for $name at $url" >&2
    exit 1
  fi

  if [[ "$latest" != "$current" ]]; then
    echo "$name $current $latest"
  fi
done
