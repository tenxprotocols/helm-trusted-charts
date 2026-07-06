#!/usr/bin/env bash
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

out=$(scripts/check-updates.sh test/fixtures/.charts.yml)
if [[ "$out" != "demo-chart 0.1.0 0.2.0" ]]; then
  echo "FAIL: expected 'demo-chart 0.1.0 0.2.0', got: '$out'" >&2
  exit 1
fi
echo "PASS: update detection (latest stable, prerelease 0.3.0-rc.1 ignored)"
