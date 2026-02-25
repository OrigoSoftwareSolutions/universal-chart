# Universal Helm Chart Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fork nixys/nxs-universal-chart, strip unused resources, add Origo-specific CRDs, and publish via GitHub Pages.

**Architecture:** Single Helm chart at repo root, no sub-charts. All nixys helper patterns preserved. New CRD templates use thin passthrough (spec passed verbatim). Published to gh-pages branch via GitHub Actions on version tags.

**Tech Stack:** Helm v3, GitHub Actions, GitHub Pages, Helm chart-releaser action (helm/chart-releaser-action)

---

## Context

The nixys chart is the starting point. The tree from their GitHub:
- Repo: https://github.com/nixys/nxs-universal-chart
- Pull with: `helm pull oci://... ` or just `git clone` and copy

**What to strip:** `traefikingressroute.yml`, `traefikingressrouteudp.yml`, `traefikmiddleware.yml`, `traefikservice.yml`, `traefiktls.yml`, `traefikserverstransport.yml`, `vmservicescrape.yml`, `sealedsecret.yml` (or similar names - check after pulling)

**What to add:**
- `templates/externalsecrets.yaml` — `ExternalSecret` (external-secrets.io/v1beta1)
- `templates/secretstores.yaml` — `SecretStore` (external-secrets.io/v1beta1)
- `templates/clustersecretstores.yaml` — `ClusterSecretStore` (external-secrets.io/v1beta1)
- `templates/clusterexternalsecrets.yaml` — `ClusterExternalSecret` (external-secrets.io/v1beta1)
- `templates/clusterissuers.yaml` — `ClusterIssuer` (cert-manager.io/v1)
- `templates/httproutes.yaml` — `HTTPRoute` (gateway.networking.k8s.io/v1)
- `templates/istiopeerauthentications.yaml` — `PeerAuthentication` (security.istio.io/v1beta1)
- `templates/istioauthorizationpolicies.yaml` — `AuthorizationPolicy` (security.istio.io/v1beta1)

**Testing approach for Helm:** Write `ci/test-values.yaml` that exercises each resource type, then run `helm template` and `helm lint`. There is no traditional unit test framework — verification is `helm template | grep <expected>` and `helm lint`.

---

## Task 1: Pull nixys chart and scaffold Origo chart

**Files:**
- Create: `Chart.yaml`
- Create: `values.yaml`
- Create: `templates/` (all nixys templates)
- Create: `ci/test-values.yaml`

**Step 1: Clone nixys chart into a temp location**

```bash
git clone --depth=1 https://github.com/nixys/nxs-universal-chart /tmp/nxs-universal-chart
```

**Step 2: Copy chart contents into the repo root**

```bash
cp -r /tmp/nxs-universal-chart/universal-chart/templates ./templates
cp /tmp/nxs-universal-chart/universal-chart/values.yaml ./values.yaml
cp /tmp/nxs-universal-chart/universal-chart/.helmignore ./.helmignore
```

**Step 3: Write Chart.yaml**

Create `Chart.yaml`:

```yaml
apiVersion: v2
name: universal-chart
description: Origo universal Helm chart for all standard Kubernetes and CRD resources
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - universal
  - origo
home: https://github.com/origo/universal-chart
sources:
  - https://github.com/origo/universal-chart
maintainers:
  - name: Origo DevOps
```

**Step 4: Verify the chart renders with default (empty) values**

```bash
helm lint .
helm template test . | head -20
```

Expected: `helm lint` outputs `1 chart(s) linted, 0 chart(s) failed`. `helm template` outputs nothing (all sections are empty `{}`).

**Step 5: Create minimal ci/test-values.yaml**

Create `ci/test-values.yaml`:

```yaml
# Smoke test: one deployment, one service
deployments:
  web:
    containers:
      - name: web
        image:
          repository: nginx
          tag: "1.25"

services:
  web:
    ports:
      - port: 80
        targetPort: 80
```

**Step 6: Verify ci values render**

```bash
helm template test . -f ci/test-values.yaml | grep "kind:"
```

Expected output contains:
```
kind: Deployment
kind: Service
```

**Step 7: Commit**

```bash
git add Chart.yaml values.yaml templates/ ci/ .helmignore
git commit -m "feat: bootstrap chart from nixys/nxs-universal-chart v2.8.1"
```

---

## Task 2: Strip Traefik, VictoriaMetrics, and SealedSecrets

**Files:**
- Delete: all `templates/traefik*.yml` files
- Delete: `templates/vmservicescrape.yml`
- Delete: `templates/sealedsecret.yml` (check exact name)
- Modify: `values.yaml` — remove corresponding sections

**Step 1: List Traefik/VM/SealedSecret template files**

```bash
ls templates/ | grep -iE "traefik|vm|sealed"
```

Note the exact filenames. Expected to find files like:
- `traefikingressroute.yml`, `traefikmiddleware.yml`, `traefikservice.yml`, `traefiktls.yml`, `traefikserverstransport.yml`
- `vmservicescrape.yml`
- `sealedsecret.yml`

**Step 2: Delete the files**

```bash
rm templates/traefik*.yml templates/vmservicescrape.yml templates/sealedsecret.yml
# Adjust names to match what you found in Step 1
```

**Step 3: Remove corresponding sections from values.yaml**

Open `values.yaml` and delete these top-level keys and their contents:
- `ingressroutes`
- `ingressroutesUDP`
- `middlewares`
- `TLSOptions`
- `TLSStores`
- `ServersTransport`
- `traefikservices`
- `vmServiceScrapes` (or `vmServiceScrape`)
- `sealedSecrets`

**Step 4: Verify lint still passes**

```bash
helm lint .
helm template test . -f ci/test-values.yaml | grep "kind:"
```

Expected: `0 chart(s) failed`. Same kinds as before (Deployment, Service).

**Step 5: Commit**

```bash
git add templates/ values.yaml
git commit -m "chore: strip Traefik, VictoriaMetrics, SealedSecrets from nixys base"
```

---

## Task 3: Add External Secrets Operator templates

**Files:**
- Create: `templates/externalsecrets.yaml`
- Create: `templates/secretstores.yaml`
- Create: `templates/clustersecretstores.yaml`
- Create: `templates/clusterexternalsecrets.yaml`
- Modify: `values.yaml`
- Modify: `ci/test-values.yaml`

**Step 1: Add test values for ExternalSecret (it should fail to render — no template yet)**

Add to `ci/test-values.yaml`:

```yaml
externalSecrets:
  my-db-secret:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws-secrets
        kind: SecretStore
      target:
        name: my-db-secret
      data:
        - secretKey: password
          remoteRef:
            key: prod/myapp/db
            property: password
```

**Step 2: Run template — verify it renders nothing for externalSecrets (key ignored)**

```bash
helm template test . -f ci/test-values.yaml | grep -i "ExternalSecret" || echo "NOT RENDERED"
```

Expected: `NOT RENDERED` (no template exists yet)

**Step 3: Create templates/externalsecrets.yaml**

```yaml
{{- range $name, $es := .Values.externalSecrets }}
{{- if not ($es.disabled | default false) }}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $es.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $es.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 4: Create templates/secretstores.yaml**

```yaml
{{- range $name, $ss := .Values.secretStores }}
{{- if not ($ss.disabled | default false) }}
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $ss.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $ss.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 5: Create templates/clustersecretstores.yaml**

```yaml
{{- range $name, $css := .Values.clusterSecretStores }}
{{- if not ($css.disabled | default false) }}
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $css.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $css.spec | nindent 2 }}
{{- end }}
{{- end }}
```

Note: `ClusterSecretStore` is cluster-scoped — no `namespace:` field.

**Step 6: Create templates/clusterexternalsecrets.yaml**

```yaml
{{- range $name, $ces := .Values.clusterExternalSecrets }}
{{- if not ($ces.disabled | default false) }}
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterExternalSecret
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $ces.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $ces.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 7: Add values.yaml sections**

Add after the `sealedSecrets` removal location in `values.yaml`:

```yaml
# -- External Secrets Operator
# @default -- See below
externalSecrets: {}
# externalSecrets:
#   my-secret:
#     spec:
#       refreshInterval: 1h
#       secretStoreRef:
#         name: my-store
#         kind: SecretStore
#       target:
#         name: my-secret
#       data: []

secretStores: {}
# secretStores:
#   my-store:
#     spec:
#       provider:
#         aws:
#           service: SecretsManager
#           region: eu-west-1

clusterSecretStores: {}
# clusterSecretStores:
#   cluster-store:
#     spec:
#       provider: {}

clusterExternalSecrets: {}
# clusterExternalSecrets:
#   cluster-secret:
#     spec: {}
```

**Step 8: Verify ExternalSecret renders**

```bash
helm template test . -f ci/test-values.yaml | grep "kind:"
```

Expected output now includes `kind: ExternalSecret`

**Step 9: Verify lint passes**

```bash
helm lint .
```

Expected: `0 chart(s) failed`

**Step 10: Commit**

```bash
git add templates/externalsecrets.yaml templates/secretstores.yaml \
        templates/clustersecretstores.yaml templates/clusterexternalsecrets.yaml \
        values.yaml ci/test-values.yaml
git commit -m "feat: add External Secrets Operator templates (ExternalSecret, SecretStore, ClusterSecretStore, ClusterExternalSecret)"
```

---

## Task 4: Add ClusterIssuer template

**Files:**
- Create: `templates/clusterissuers.yaml`
- Modify: `values.yaml`
- Modify: `ci/test-values.yaml`

**Step 1: Add test values for ClusterIssuer**

Add to `ci/test-values.yaml`:

```yaml
clusterIssuers:
  letsencrypt-prod:
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: devops@origo.is
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
          - dns01:
              azureDNS:
                subscriptionID: fake-sub-id
                resourceGroupName: fake-rg
                hostedZoneName: origo.is
```

**Step 2: Create templates/clusterissuers.yaml**

```yaml
{{- range $name, $ci := .Values.clusterIssuers }}
{{- if not ($ci.disabled | default false) }}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $ci.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $ci.spec | nindent 2 }}
{{- end }}
{{- end }}
```

Note: `ClusterIssuer` is cluster-scoped — no `namespace:` field.

**Step 3: Add values.yaml section**

Add after the `issuers: {}` line in `values.yaml`:

```yaml
clusterIssuers: {}
# clusterIssuers:
#   letsencrypt-prod:
#     spec:
#       acme:
#         server: https://acme-v02.api.letsencrypt.org/directory
#         email: devops@example.com
#         privateKeySecretRef:
#           name: letsencrypt-prod
#         solvers: []
```

**Step 4: Verify render and lint**

```bash
helm template test . -f ci/test-values.yaml | grep "kind:"
helm lint .
```

Expected: `kind: ClusterIssuer` appears, `0 chart(s) failed`

**Step 5: Commit**

```bash
git add templates/clusterissuers.yaml values.yaml ci/test-values.yaml
git commit -m "feat: add ClusterIssuer template"
```

---

## Task 5: Add HTTPRoute template

**Files:**
- Create: `templates/httproutes.yaml`
- Modify: `values.yaml`
- Modify: `ci/test-values.yaml`

**Step 1: Add test values for HTTPRoute**

Add to `ci/test-values.yaml`:

```yaml
httpRoutes:
  web:
    spec:
      parentRefs:
        - name: istio-gateway
          namespace: istio-ingress
      hostnames:
        - app.origo.is
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: web
              port: 80
```

**Step 2: Create templates/httproutes.yaml**

```yaml
{{- range $name, $hr := .Values.httpRoutes }}
{{- if not ($hr.disabled | default false) }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $hr.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $hr.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 3: Add values.yaml section**

Add after the `ingresses: {}` line in `values.yaml`:

```yaml
httpRoutes: {}
# httpRoutes:
#   my-app:
#     spec:
#       parentRefs:
#         - name: istio-gateway
#           namespace: istio-ingress
#       hostnames:
#         - app.example.com
#       rules: []
```

**Step 4: Verify render and lint**

```bash
helm template test . -f ci/test-values.yaml | grep "kind:"
helm lint .
```

Expected: `kind: HTTPRoute` appears, `0 chart(s) failed`

**Step 5: Commit**

```bash
git add templates/httproutes.yaml values.yaml ci/test-values.yaml
git commit -m "feat: add HTTPRoute template (Gateway API)"
```

---

## Task 6: Add Istio security templates

**Files:**
- Create: `templates/istiopeerauthentications.yaml`
- Create: `templates/istioauthorizationpolicies.yaml`
- Modify: `values.yaml`
- Modify: `ci/test-values.yaml`

**Step 1: Add test values**

Add to `ci/test-values.yaml`:

```yaml
istioPeerAuthentications:
  default:
    spec:
      mtls:
        mode: STRICT

istioAuthorizationPolicies:
  deny-all:
    spec:
      action: DENY
      rules:
        - {}
```

**Step 2: Create templates/istiopeerauthentications.yaml**

```yaml
{{- range $name, $pa := .Values.istioPeerAuthentications }}
{{- if not ($pa.disabled | default false) }}
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $pa.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $pa.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 3: Create templates/istioauthorizationpolicies.yaml**

```yaml
{{- range $name, $ap := .Values.istioAuthorizationPolicies }}
{{- if not ($ap.disabled | default false) }}
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels: {{- include "helpers.app.selectorLabels" $ | nindent 4 }}
  {{- with $ap.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $ap.spec | nindent 2 }}
{{- end }}
{{- end }}
```

**Step 4: Add values.yaml sections**

Add after `istioDestinationRules: {}` in `values.yaml`:

```yaml
istioPeerAuthentications: {}
# istioPeerAuthentications:
#   default:
#     spec:
#       mtls:
#         mode: STRICT

istioAuthorizationPolicies: {}
# istioAuthorizationPolicies:
#   deny-all:
#     spec:
#       action: DENY
#       rules:
#         - {}
```

**Step 5: Verify render and lint**

```bash
helm template test . -f ci/test-values.yaml | grep "kind:"
helm lint .
```

Expected output includes `kind: PeerAuthentication` and `kind: AuthorizationPolicy`, `0 chart(s) failed`

**Step 6: Full render smoke test — verify all expected kinds**

```bash
helm template test . -f ci/test-values.yaml | grep "^kind:" | sort | uniq
```

Expected to see:
```
kind: AuthorizationPolicy
kind: ClusterExternalSecret
kind: ClusterIssuer
kind: ClusterSecretStore
kind: Deployment
kind: ExternalSecret
kind: HTTPRoute
kind: PeerAuthentication
kind: SecretStore
kind: Service
```

**Step 7: Commit**

```bash
git add templates/istiopeerauthentications.yaml templates/istioauthorizationpolicies.yaml \
        values.yaml ci/test-values.yaml
git commit -m "feat: add Istio PeerAuthentication and AuthorizationPolicy templates"
```

---

## Task 7: Expand ci/test-values.yaml to cover all nixys resource types

This ensures that changes never break existing nixys templates.

**Files:**
- Modify: `ci/test-values.yaml`

**Step 1: Add coverage for all remaining resource types**

Add to `ci/test-values.yaml`:

```yaml
statefulSets:
  db:
    containers:
      - name: db
        image:
          repository: postgres
          tag: "15"
    volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi

cronJobs:
  cleanup:
    schedule: "0 2 * * *"
    containers:
      - name: cleanup
        image:
          repository: busybox
          tag: latest

configMaps:
  app-config:
    data:
      APP_ENV: production

hpa:
  web:
    minReplicas: 1
    maxReplicas: 5
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 70

certificates:
  app-tls:
    spec:
      secretName: app-tls-secret
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
        - app.origo.is

serviceMonitors:
  web:
    spec:
      selector:
        matchLabels:
          app: web
      endpoints:
        - port: http
          path: /metrics

istioVirtualServices:
  web:
    spec:
      hosts:
        - app.origo.is
      http:
        - route:
            - destination:
                host: web
                port:
                  number: 80

externalSecrets:
  app-secrets:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: cluster-store
        kind: ClusterSecretStore
      target:
        name: app-secrets
      data:
        - secretKey: DB_PASSWORD
          remoteRef:
            key: prod/app/db
            property: password
```

**Step 2: Run full render and check all kinds appear**

```bash
helm template test . -f ci/test-values.yaml | grep "^kind:" | sort | uniq
```

Expected to see 15+ distinct kinds.

**Step 3: Run lint**

```bash
helm lint .
```

Expected: `0 chart(s) failed`

**Step 4: Commit**

```bash
git add ci/test-values.yaml
git commit -m "test: expand ci/test-values.yaml to cover all resource types"
```

---

## Task 8: Set up GitHub Actions for GitHub Pages publishing

**Files:**
- Create: `.github/workflows/release.yaml`
- Create: `.github/workflows/lint.yaml`

**Step 1: Create .github/workflows/lint.yaml**

This runs on every PR to catch template errors:

```yaml
name: Lint Chart

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Lint
        run: helm lint . --strict

      - name: Template smoke test
        run: helm template test . -f ci/test-values.yaml > /dev/null
```

**Step 2: Create .github/workflows/release.yaml**

Uses the official Helm chart-releaser action:

```yaml
name: Release Chart

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pages: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure Git
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Run chart-releaser
        uses: helm/chart-releaser-action@v1.6.0
        with:
          charts_dir: .
          config: cr.yaml
        env:
          CR_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
```

Note: chart-releaser expects charts in subdirectories by default. Since our chart is at repo root, we need a `cr.yaml` config.

**Step 3: Create cr.yaml**

```yaml
# chart-releaser config
# chart is at repo root, not in a charts/ subdirectory
charts-repo-url: https://<your-github-org>.github.io/universal-chart
```

Replace `<your-github-org>` with the actual GitHub org/user name.

**Step 4: Enable GitHub Pages in repo settings**

In the GitHub repository settings:
1. Go to Settings → Pages
2. Set Source to: `Deploy from a branch`
3. Set Branch to: `gh-pages`, folder `/` (root)
4. Save

This is a one-time manual step.

**Step 5: Commit workflows**

```bash
git add .github/ cr.yaml
git commit -m "ci: add lint workflow and GitHub Pages release workflow"
```

**Step 6: Test the lint workflow locally (optional)**

```bash
# If you have act installed (https://github.com/nektos/act):
act push -W .github/workflows/lint.yaml
```

---

## Task 9: First release

**Step 1: Ensure Chart.yaml version matches intended release**

Open `Chart.yaml` and confirm `version: 0.1.0`.

**Step 2: Tag the release**

```bash
git tag v0.1.0
git push origin main --tags
```

**Step 3: Verify GitHub Actions completes**

Watch the Actions tab in GitHub. The release workflow should:
1. Package the chart
2. Create a GitHub release with the `.tgz` artifact
3. Push `index.yaml` to `gh-pages` branch

**Step 4: Verify the Helm repo works**

```bash
helm repo add origo https://<your-github-org>.github.io/universal-chart
helm repo update
helm search repo origo/universal-chart
```

Expected:
```
NAME                     CHART VERSION  APP VERSION  DESCRIPTION
origo/universal-chart    0.1.0          1.0.0        Origo universal Helm chart...
```

---

## Summary of All New Files

```
Chart.yaml
values.yaml
.helmignore
cr.yaml
ci/
  test-values.yaml
templates/
  (all nixys templates, minus Traefik/VM/SealedSecrets)
  externalsecrets.yaml          ← new
  secretstores.yaml             ← new
  clustersecretstores.yaml      ← new
  clusterexternalsecrets.yaml   ← new
  clusterissuers.yaml           ← new
  httproutes.yaml               ← new
  istiopeerauthentications.yaml ← new
  istioauthorizationpolicies.yaml ← new
.github/
  workflows/
    lint.yaml
    release.yaml
docs/
  plans/
    2026-02-25-universal-chart-design.md
    2026-02-25-universal-chart-implementation.md
```
