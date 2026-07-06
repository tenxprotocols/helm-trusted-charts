#!/usr/bin/env bash
# Proves chart-vendor applies charts/patches/<chart>/*.patch to the vendored tree.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
server_pid=""
cleanup() {
  [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

server_pid=$(test/serve-fixture-repo.sh "$tmp/repo")

mkdir -p "$tmp/charts"
cp -R test/fixtures/patches "$tmp/charts/patches"

chart-vendor --config-file test/fixtures/.charts.yml --charts-root "$tmp/charts"

grep -q 'message: patched' "$tmp/charts/demo-chart/templates/configmap.yaml"
echo "PASS: patch applied to vendored chart"
