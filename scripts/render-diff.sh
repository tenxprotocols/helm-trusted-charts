#!/usr/bin/env bash
# Unified diff of rendered manifests for <chart> between <base-ref> and HEAD.
# Uses ci/<chart>/values-*.yaml when present; chart defaults otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."

chart="$1"
base="${2:-origin/main}"

render() {
  local chart_dir="$1" values_dir="$2" out="$3"
  if [[ ! -d "$chart_dir" ]]; then
    : > "$out"
    return
  fi
  local args=() f
  if compgen -G "$values_dir/values-*.yaml" > /dev/null; then
    for f in "$values_dir"/values-*.yaml; do
      args+=(-f "$f")
    done
  fi
  if ! helm template "$chart" "$chart_dir" ${args[@]+"${args[@]}"} > "$out" 2> "$out.err"; then
    printf '# helm template failed:\n' > "$out"
    cat "$out.err" >> "$out"
  fi
}

tmp=$(mktemp -d)
cleanup() {
  git worktree remove --force "$tmp/base" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

git worktree add --detach "$tmp/base" "$base" >/dev/null 2>&1

render "charts/$chart" "ci/$chart" "$tmp/head.yaml"
render "$tmp/base/charts/$chart" "$tmp/base/ci/$chart" "$tmp/base.yaml"

diff -u --label "$chart @ $base" --label "$chart @ HEAD" \
  "$tmp/base.yaml" "$tmp/head.yaml" || true
