# Universal Helm Chart — Design Document

**Date:** 2026-02-25
**Status:** Approved

---

## Overview

A single Helm chart that replaces all per-project chart directories in the Origo GitOps repository. Teams reference the chart directly from ArgoCD and supply a `values.yaml` — no scaffolding, no per-project `Chart.yaml`, no template files to maintain.

**Base:** Fork of [nixys/nxs-universal-chart](https://github.com/nixys/nxs-universal-chart) v2.8.1 (Apache 2.0), adapted to Origo's stack.

**Distribution:** GitHub Pages Helm repository at `https://origo.github.io/universal-chart`

---

## Architecture

Single chart, no sub-charts, no dependencies. One template file per resource type in `templates/`. All core nixys design patterns are preserved:

- `range $name, $val` over maps — the map key becomes the resource name
- Three-level merging: instance → `*General` → `generic` → hardcoded default
- `helpers.tplvalues.render` — allows Helm template expressions inside value strings
- Shared `helpers.pod` partial used by all workload types (Deployment, StatefulSet, Job, CronJob, hooks)
- `extraDeploy` escape hatch for arbitrary manifests not covered by native templates

---

## Resource Coverage

### Kept from nixys

| Category | Resources |
|---|---|
| Workloads | Deployment, StatefulSet, Job, CronJob, Helm hook Jobs |
| Networking | Service, Ingress |
| Config / Storage | ConfigMap, Secret, PVC, ServiceAccount + Role/ClusterRole |
| Scaling / Policy | HPA, PDB |
| cert-manager | Certificate, Issuer |
| Prometheus Operator | ServiceMonitor |
| Istio | VirtualService, Gateway, DestinationRule |
| Escape hatch | extraDeploy |

### Stripped from nixys

- All Traefik resources (IngressRoute, IngressRouteUDP, Middleware, TraefikService, TLSOption, TLSStore, ServersTransport)
- VictoriaMetrics `VMServiceScrape`
- `SealedSecret`

### Added for Origo

| Category | Resources | API Version |
|---|---|---|
| External Secrets Operator | ExternalSecret | `external-secrets.io/v1beta1` |
| External Secrets Operator | SecretStore | `external-secrets.io/v1beta1` |
| External Secrets Operator | ClusterSecretStore | `external-secrets.io/v1beta1` |
| External Secrets Operator | ClusterExternalSecret | `external-secrets.io/v1beta1` |
| cert-manager | ClusterIssuer | `cert-manager.io/v1` |
| Gateway API | HTTPRoute | `gateway.networking.k8s.io/v1` |
| Istio security | PeerAuthentication | `security.istio.io/v1beta1` |
| Istio security | AuthorizationPolicy | `security.istio.io/v1beta1` |

---

## New Template Pattern (thin passthrough)

New CRD templates use a minimal range-over-map pattern. The `spec` block is passed through verbatim — no abstraction layer. This preserves full CRD flexibility while adding consistent naming, labels, and the `.disabled` escape hatch.

```yaml
# Example: externalsecrets.yaml
{{- range $name, $es := .Values.externalSecrets }}
{{- if not ($es.disabled | default false) }}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
spec:
  {{- toYaml $es.spec | nindent 2 }}
{{- end }}
{{- end }}
```

The same pattern applies to SecretStore, ClusterSecretStore, ClusterExternalSecret, HTTPRoute, PeerAuthentication, AuthorizationPolicy, and ClusterIssuer.

Helpers will be added to these templates only when repeated patterns emerge across multiple apps (YAGNI).

---

## values.yaml Structure

All nixys sections are preserved. The following sections are added:

```yaml
# External Secrets Operator
externalSecrets: {}
secretStores: {}
clusterSecretStores: {}
clusterExternalSecrets: {}

# cert-manager (supplements existing certificates/issuers)
clusterIssuers: {}

# Gateway API
httpRoutes: {}

# Istio security
istioPeerAuthentications: {}
istioAuthorizationPolicies: {}
```

---

## GitHub Pages Distribution

- `main` branch holds chart source
- Git tags of the form `v*.*.*` trigger a GitHub Actions workflow that:
  1. Runs `helm package`
  2. Runs `helm repo index --merge` against the existing `gh-pages` index
  3. Pushes the packaged chart and updated `index.yaml` to the `gh-pages` branch
- Teams add the repo once: `helm repo add origo https://origo.github.io/universal-chart`
- ArgoCD `Application` manifests pin to a specific chart version via `targetRevision`

---

## Out of Scope

- CRD installation (operators are assumed to be pre-installed in the cluster)
- ArgoCD `Application` / `AppProject` resources (too meta, managed separately)
- Kyverno `ClusterPolicy` resources (managed in the dedicated kyverno chart)
- Argo Rollouts (not currently in use)
