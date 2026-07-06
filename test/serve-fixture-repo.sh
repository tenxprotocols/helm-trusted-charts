#!/usr/bin/env bash
# Packages the fixture chart (three versions), indexes a helm repo in $1,
# serves it at http://127.0.0.1:8123, prints the server PID on stdout.
set -euo pipefail
cd "$(dirname "$0")/.."

out="$1"
mkdir -p "$out"
helm package test/fixtures/chart-src/demo-chart -d "$out" >/dev/null
helm package test/fixtures/chart-src/demo-chart -d "$out" --version 0.2.0 >/dev/null
helm package test/fixtures/chart-src/demo-chart -d "$out" --version 0.3.0-rc.1 >/dev/null
helm repo index "$out" --url http://127.0.0.1:8123

python3 -m http.server 8123 --directory "$out" --bind 127.0.0.1 >/dev/null 2>&1 &
pid=$!

for _ in $(seq 1 25); do
  if curl -fs "http://127.0.0.1:8123/index.yaml" >/dev/null 2>&1; then
    echo "$pid"
    exit 0
  fi
  sleep 0.2
done
kill "$pid" 2>/dev/null || true
echo "fixture repo server failed to start" >&2
exit 1
