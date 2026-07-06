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
    latest=$(oras repo tags "${url#oci://}/$name" \
      | grep -v -- - | sort -V | tail -1)
  else
    latest=$(curl -fsSL "$url/index.yaml" \
      | yq ".entries.\"$name\"[].version" \
      | grep -v -- - | sort -V | tail -1)
  fi

  if [[ -z "$latest" ]]; then
    echo "error: no stable versions found for $name at $url" >&2
    exit 1
  fi

  if [[ "$latest" != "$current" ]]; then
    echo "$name $current $latest"
  fi
done
