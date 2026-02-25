# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Validate the chart
helm lint . --strict

# Render all resources using CI test values (smoke test)
helm template test . -f ci/test-values.yaml

# Render against a live cluster (resolves Capabilities.APIVersions)
helm template test . -f ci/test-values.yaml --api-versions networking.istio.io/v1beta1

# Check what kinds are rendered
helm template test . -f ci/test-values.yaml | grep "^kind:" | sort | uniq

# Release: tag and push (triggers GitHub Actions → gh-pages publish)
git tag v0.X.Y && git push origin main --tags
```

## Architecture

This is a fork of [nixys/nxs-universal-chart](https://github.com/nixys/nxs-universal-chart) adapted for Origo. The chart lives at the repo root (no subdirectory). It is published to GitHub Pages (`gh-pages` branch) via `.github/workflows/release.yaml` on `v*.*.*` tags.

### Core pattern

Every resource type follows the same structure:

```yaml
{{- range $name, $val := .Values.<section> }}
{{- if not ($val.disabled | default false) }}
---
apiVersion: <from capabilities helper or hardcoded>
kind: <Kind>
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  ...
spec:
  {{- toYaml $val.spec | nindent 2 }}   # thin passthrough for CRDs
  # OR inline spec fields for core k8s resources
{{- end }}
{{- end }}
```

The map key (`$name`) becomes the resource name. `releasePrefix` prepends to all names.

### Three-level value merging for workloads

Instance → `*General` → `generic` (global) → hardcoded default. Implemented via `dig` for scalars. The `helpers.tplvalues.render` helper (in `_tplvalues.tpl`) evaluates Helm template expressions inside value strings — users can write `{{ .Release.Name }}-db` anywhere in values.

### helpers/ directory

| File | Purpose |
|---|---|
| `_app.tpl` | `helpers.app.fullname`, labels, selector labels |
| `_pod.tpl` | `helpers.pod` — shared pod spec for all workloads |
| `_capabilities.tpl` | apiVersion resolution (semver or Capabilities check + hardcoded fallback) |
| `_volumes.tpl` | `helpers.volumes.typed` — typed volume shorthand (`type: configMap/secret/pvc/emptyDir`) |
| `_tplvalues.tpl` | `helpers.tplvalues.render` — evaluate template expressions in values |
| `_configmaps.tpl` / `_secrets.tpl` | Auto-generate companion ConfigMap/Secret from `envs`/`secretEnvs` |
| `_workloads.tpl` | `helpers.workload.checksum` for config-reload annotations |
| `_affinities.tpl` | Affinity presets (`soft`/`hard` for pod and node) |

### apiVersion resolution

Core k8s resources use `semverCompare` against kubeVersion. Istio networking resources (`VirtualService`, `Gateway`, `DestinationRule`) use `.Capabilities.APIVersions.Has "networking.istio.io/v1"` with a hardcoded fallback of `networking.istio.io/v1beta1`. When running `helm template` without a live cluster, the fallback always fires.

### New CRD templates (Origo additions)

These use **thin passthrough** — the entire `spec:` block is `toYaml`'d verbatim. No abstraction layer. Resources added beyond nixys base:

- **External Secrets Operator**: `ExternalSecret`, `SecretStore`, `ClusterSecretStore`, `ClusterExternalSecret`
- **cert-manager**: `ClusterIssuer` (nixys only has `Issuer`)
- **Gateway API**: `HTTPRoute`
- **Istio security**: `PeerAuthentication`, `AuthorizationPolicy`

Cluster-scoped resources (`ClusterSecretStore`, `ClusterExternalSecret`, `ClusterIssuer`) intentionally have no `namespace:` field.

### Workload-specific features

- **`diagnosticMode.enabled: true`** — overrides all container commands with `sleep infinity` and disables all probes globally
- **`envs` / `secretEnvs`** — auto-creates a companion ConfigMap/Secret and injects via `envFrom`
- **`volumes[].type`** — shorthand for configMap/secret/pvc/emptyDir instead of raw Kubernetes volume syntax
- **`hooks`** — first-class Helm lifecycle Jobs (pre/post-install/upgrade) with proper hook annotations
- **`extraDeploy`** — raw manifest escape hatch; values are evaluated through `tplvalues.render` so template expressions still work

### Stripped from nixys base

Traefik, VictoriaMetrics `VMServiceScrape`, and SealedSecrets (including the embedded block that was in `secret.yml`) are not present.
