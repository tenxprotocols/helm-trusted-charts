#!/usr/bin/env bash
# Prints the names of charts changed since merge-base(<base-ref>, HEAD).
# Both charts/<name>/** and charts/patches/<name>/** count.
set -euo pipefail
cd "$(dirname "$0")/.."

base="${1:-origin/main}"
merge_base=$(git merge-base "$base" HEAD)

git diff --name-only "$merge_base" HEAD -- charts/ \
  | awk -F/ '$2 == "patches" { print $3 } $2 != "patches" { print $2 }' \
  | sed '/^$/d' | sort -u
