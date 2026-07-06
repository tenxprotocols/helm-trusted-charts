#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

out=$(scripts/render-diff.sh external-dns HEAD)
if [[ -n "$out" ]]; then
  echo "FAIL: expected empty diff against HEAD, got:" >&2
  echo "$out" >&2
  exit 1
fi
echo "PASS: render-diff is empty against HEAD"
