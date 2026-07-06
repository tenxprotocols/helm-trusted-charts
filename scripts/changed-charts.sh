#!/usr/bin/env bash
# Prints the names of charts changed since merge-base(<base-ref>, HEAD).
# Counts charts/<name>/**, charts/patches/<name>/**, and publish.yml
# entry changes (a revision bump must re-run the publish gates).
set -euo pipefail
cd "$(dirname "$0")/.."

base="${1:-origin/main}"
merge_base=$(git merge-base "$base" HEAD)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git diff --name-only "$merge_base" HEAD -- charts/ \
  | awk -F/ '$2 == "patches" { print $3 } $2 != "patches" { print $2 }' \
  | sed '/^$/d' > "$tmp/changed"

# publish.yml: chart entries added, removed, or with a changed revision.
dump_entries() {
  yq '.charts // {} | to_entries[] | .key + " " + (.value.revision // "null" | tostring)' "$1"
}
if ! git show "$merge_base:publish.yml" > "$tmp/pub-old.yml" 2>/dev/null; then
  echo 'charts: {}' > "$tmp/pub-old.yml"
fi
{ dump_entries "$tmp/pub-old.yml"; dump_entries publish.yml; } \
  | sort | uniq -u | awk '{print $1}' >> "$tmp/changed"

sort -u "$tmp/changed" | sed '/^$/d'
