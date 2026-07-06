#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/lib.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/charts/plain" "$tmp/charts/patched" "$tmp/charts/patches/patched"
printf 'apiVersion: v2\nname: plain\nversion: 1.2.3\n' > "$tmp/charts/plain/Chart.yaml"
printf 'apiVersion: v2\nname: patched\nversion: 4.5.6\n' > "$tmp/charts/patched/Chart.yaml"
touch "$tmp/charts/patches/patched/0001-x.patch"
printf 'charts:\n  patched:\n    revision: 2\n' > "$tmp/publish.yml"

export CHARTS_ROOT="$tmp/charts" PUBLISH_FILE="$tmp/publish.yml"

fail() { echo "FAIL: $1" >&2; exit 1; }

[[ "$(compute_publish_version plain)" == "1.2.3" ]] \
  || fail "unpatched chart must publish upstream version verbatim"

[[ "$(compute_publish_version patched)" == "4.5.6+tenx.2" ]] \
  || fail "patched chart must get +tenx.<revision> build metadata"

printf 'charts: {}\n' > "$tmp/publish.yml"
if compute_publish_version patched 2>/dev/null; then
  fail "patches without a revision entry must error"
fi

printf 'charts:\n  plain:\n    revision: 1\n' > "$tmp/publish.yml"
if compute_publish_version plain 2>/dev/null; then
  fail "revision entry without patches must error"
fi

echo "PASS: publish version computation"
