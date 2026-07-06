# tenx-helm-trusted-charts

Vendored third-party Helm charts: pulled from upstream, reviewed as source,
optionally patched, and republished to
`oci://ghcr.io/tenxprotocols/helm-trusted-charts/<chart>`.

Why: charts consumed straight from upstream repos are an unreviewed supply
chain into our clusters. Charts here are pinned in `.charts.yml`, committed
as full source, gated by CI, and served from our own registry. Design doc:
`tenx-blockchain-infra/docs/plans/2026-07-06-helm-chart-provenance-design.md`.

## Consuming a mirrored chart

Point the consumer at our registry — same chart name, same version:

```yaml
repoURL: oci://ghcr.io/tenxprotocols/helm-trusted-charts
chart: external-dns
targetRevision: 1.20.0
```

Patched charts carry a `+tenx.N` suffix (OCI tag: `1.20.0_tenx.1` — helm and
ArgoCD translate `+`/`_` automatically).

Artifacts are cosign-signed (keyless) by the publish workflow. To verify:

```bash
cosign verify \
  --certificate-identity-regexp 'https://github.com/tenxprotocols/helm-trusted-charts/\.github/workflows/publish\.yaml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/tenxprotocols/helm-trusted-charts/<chart>:<version>
```

## Importing a new chart

1. Add an entry to `.charts.yml`:
   ```yaml
   - name: my-chart
     version: 1.2.3
     repository:
       url: https://example.github.io/charts
   ```
2. `mise exec -- chart-vendor`
3. Open a PR. The full vendored source is the review surface; CI adds a
   rendered-manifest diff comment.
4. Merge. The publish workflow pushes the chart and cosign-signs it.
5. One-time: make the new ghcr package public in the org package settings.

## Patching a chart

The committed `charts/<name>/` tree is upstream + patches, re-applied on
every re-vendor. Patches must not touch `Chart.yaml` (chart-vendor filters
it out; version suffixing is handled at publish time).

1. Edit files under `charts/<name>/` directly.
2. Capture the delta as a patch, then reset the tree:
   ```bash
   mkdir -p charts/patches/<name>
   git diff --relative=charts > charts/patches/<name>/0001-describe-change.patch
   git checkout -- charts/<name>
   ```
3. Re-vendor (fetches pristine upstream, applies your patch):
   ```bash
   mise exec -- chart-vendor
   ```
4. Set the publish revision in `publish.yml`:
   ```yaml
   charts:
     my-chart:
       revision: 1   # bump whenever patches change for the same upstream version
   ```
5. Open a PR as usual.

## Updates

The `update-bot` workflow (Mondays, or `gh workflow run update-bot`) opens
one PR per chart with a newer stable upstream version. Patches that no
longer apply fail that chart's update inside the workflow run — rebase the
patch files and re-run. Review the source diff and the rendered-manifest
diff comment, then merge; merging publishes.

The bot needs the `UPDATE_BOT_TOKEN` repo secret (fine-grained PAT,
Contents: read/write + Pull requests: read/write) — without it, PR
creation is blocked by the org's Actions settings and bot PRs would not
trigger CI.

## CI gates (pr-checks)

- `chart-vendor --check` — committed tree must exactly equal
  `.charts.yml` + patches (blocks hand-edits that bypass patch files)
- `helm lint` + `helm template` on every chart
- script test suite (`test/`)
- publish preflight — the computed version must not already be published
  (published versions are immutable)
- rendered-manifest diff comment (values from `ci/<chart>/values-*.yaml`
  when present)
