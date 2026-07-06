#!/usr/bin/env bash
# Shared helpers for tenx-helm-trusted-charts scripts. Source this file.

CHARTS_ROOT="${CHARTS_ROOT:-charts}"
PUBLISH_FILE="${PUBLISH_FILE:-publish.yml}"

# compute_publish_version <chart>
# Prints the version to publish: the upstream version verbatim, or
# <upstream>+tenx.<revision> when the chart carries patches.
compute_publish_version() {
  local chart="$1"
  local upstream revision has_patches=false

  upstream=$(yq '.version' "$CHARTS_ROOT/$chart/Chart.yaml")
  revision=$(yq ".charts.\"$chart\".revision // 0" "$PUBLISH_FILE")

  if compgen -G "$CHARTS_ROOT/patches/$chart/*.patch" > /dev/null; then
    has_patches=true
  fi

  if $has_patches && (( revision < 1 )); then
    echo "error: $chart has patches but no revision >= 1 in $PUBLISH_FILE" >&2
    return 1
  fi
  if ! $has_patches && (( revision >= 1 )); then
    echo "error: $chart has revision $revision in $PUBLISH_FILE but no patches" >&2
    return 1
  fi

  if (( revision >= 1 )); then
    echo "${upstream}+tenx.${revision}"
  else
    echo "$upstream"
  fi
}
