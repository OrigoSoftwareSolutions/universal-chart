# Helm Best Practices Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add kubeconform schema validation, helm-unittest unit tests, Trivy security scanning, and helm-docs generation to the universal-chart CI pipeline.

**Architecture:** Rename the existing `release.yaml` to `ci.yaml` and extend it with four new jobs (lint gains kubeconform, new unittest job, new security job, new docs-check job). A separate `docs.yaml` auto-commits README on main push. Test suites live under `universal-chart/tests/`.

**Tech Stack:** GitHub Actions, Helm 3.14, kubeconform v0.6.7, helm-unittest v0.4.4, helm-docs v1.13.1, Trivy (aquasecurity/trivy-action).

---

### Task 1: Restructure workflow — rename and split jobs

**Files:**
- Delete: `.github/workflows/release.yaml`
- Create: `.github/workflows/ci.yaml`

The new `ci.yaml` has the same `lint` and `release` jobs as before, plus placeholders for the new jobs we'll add in subsequent tasks. The `release` job now `needs: [lint, unittest, security]`.

**Step 1: Create `.github/workflows/ci.yaml`**

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

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
        run: helm lint universal-chart/ --strict

      - name: Install kubeconform
        run: |
          curl -sLO https://github.com/yannh/kubeconform/releases/download/v0.6.7/kubeconform-linux-amd64.tar.gz
          tar -xzf kubeconform-linux-amd64.tar.gz
          sudo mv kubeconform /usr/local/bin/

      - name: Schema validation
        run: |
          helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
            | kubeconform \
              -strict \
              -ignore-missing-schemas \
              -kubernetes-version 1.28.0 \
              -schema-location default \
              -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{`{{.Group}}`}}/{{`{{.ResourceKind}}_{{.ResourceAPIVersion}}`}}.json'

  unittest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Install helm-unittest plugin
        run: helm plugin install https://github.com/helm-unittest/helm-unittest --version 0.4.4

      - name: Run unit tests
        run: helm unittest universal-chart/ --strict --file 'tests/*.yaml'

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Render manifests
        run: helm template test universal-chart/ -f universal-chart/ci/test-values.yaml > /tmp/rendered.yaml

      - name: Trivy security scan
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: config
          scan-ref: /tmp/rendered.yaml
          severity: HIGH,CRITICAL
          exit-code: ${{ github.event_name == 'push' && '1' || '0' }}
          format: table

  docs-check:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install helm-docs
        run: |
          curl -sLO https://github.com/norwoodj/helm-docs/releases/download/v1.13.1/helm-docs_1.13.1_Linux_x86_64.tar.gz
          tar -xzf helm-docs_1.13.1_Linux_x86_64.tar.gz helm-docs
          sudo mv helm-docs /usr/local/bin/

      - name: Check docs are up to date
        run: |
          helm-docs --chart-search-root universal-chart/
          git diff --exit-code universal-chart/README.md \
            || (echo "ERROR: README.md is out of date. Run 'helm-docs --chart-search-root universal-chart/' locally and commit." && exit 1)

  release:
    needs: [lint, unittest, security]
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Log in to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | helm registry login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Package chart
        run: helm package universal-chart/

      - name: Push to GHCR
        run: helm push universal-chart-*.tgz oci://ghcr.io/origosoftwaresolutions
```

**Step 2: Delete the old file and verify new one**

```bash
git rm .github/workflows/release.yaml
helm lint universal-chart/ --strict
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

**Step 3: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: restructure workflow — rename to ci.yaml, add unittest/security/docs-check jobs"
```

---

### Task 2: Create helm-unittest test suites

**Files:**
- Create: `universal-chart/tests/deployment_test.yaml`
- Create: `universal-chart/tests/service_test.yaml`
- Create: `universal-chart/tests/externalsecret_test.yaml`
- Create: `universal-chart/tests/clusterissuer_test.yaml`
- Create: `universal-chart/tests/httproute_test.yaml`

helm-unittest test files use the `.yaml` extension and live in a `tests/` directory inside the chart. Each suite specifies which template file(s) to test and a list of test cases with assertions.

**Step 1: Create `universal-chart/tests/deployment_test.yaml`**

```yaml
suite: deployment
templates:
  - deployment.yml
tests:
  - it: renders a Deployment with correct kind and apiVersion
    set:
      deployments.web.containers[0].name: web
      deployments.web.containers[0].image: nginx
      deployments.web.containers[0].imageTag: "1.25"
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: apiVersion
          value: apps/v1
      - matchRegex:
          path: metadata.name
          pattern: -web$
      - isNotEmpty:
          path: metadata.labels

  - it: respects the disabled flag
    set:
      deployments.web.disabled: true
      deployments.web.containers[0].name: web
      deployments.web.containers[0].image: nginx
      deployments.web.containers[0].imageTag: "1.25"
    asserts:
      - hasDocuments:
          count: 0
```

**Step 2: Create `universal-chart/tests/service_test.yaml`**

```yaml
suite: service
templates:
  - svc.yml
tests:
  - it: renders a Service with correct kind
    set:
      services.web.ports[0].port: 80
      services.web.ports[0].targetPort: 80
    asserts:
      - isKind:
          of: Service
      - equal:
          path: apiVersion
          value: v1
      - matchRegex:
          path: metadata.name
          pattern: -web$
```

**Step 3: Create `universal-chart/tests/externalsecret_test.yaml`**

```yaml
suite: externalsecret
templates:
  - externalsecrets.yaml
tests:
  - it: renders an ExternalSecret with namespace
    set:
      externalSecrets.my-secret.spec.refreshInterval: 1h
      externalSecrets.my-secret.spec.secretStoreRef.name: aws-store
      externalSecrets.my-secret.spec.secretStoreRef.kind: SecretStore
      externalSecrets.my-secret.spec.target.name: my-secret
    asserts:
      - isKind:
          of: ExternalSecret
      - equal:
          path: apiVersion
          value: external-secrets.io/v1beta1
      - isNotEmpty:
          path: metadata.namespace
      - equal:
          path: spec.secretStoreRef.name
          value: aws-store
```

**Step 4: Create `universal-chart/tests/clusterissuer_test.yaml`**

```yaml
suite: clusterissuer
templates:
  - clusterissuers.yaml
tests:
  - it: renders a ClusterIssuer without namespace
    set:
      clusterIssuers.letsencrypt.spec.acme.server: https://acme-v02.api.letsencrypt.org/directory
      clusterIssuers.letsencrypt.spec.acme.email: admin@example.com
    asserts:
      - isKind:
          of: ClusterIssuer
      - equal:
          path: apiVersion
          value: cert-manager.io/v1
      - notExists:
          path: metadata.namespace
```

**Step 5: Create `universal-chart/tests/httproute_test.yaml`**

```yaml
suite: httproute
templates:
  - httproutes.yaml
tests:
  - it: renders an HTTPRoute with correct apiVersion
    set:
      httpRoutes.my-route.spec.parentRefs[0].name: gateway
      httpRoutes.my-route.spec.rules[0].matches[0].path.type: PathPrefix
      httpRoutes.my-route.spec.rules[0].matches[0].path.value: /
    asserts:
      - isKind:
          of: HTTPRoute
      - equal:
          path: apiVersion
          value: gateway.networking.k8s.io/v1
      - isNotEmpty:
          path: metadata.namespace
```

**Step 6: Verify tests run locally (requires helm-unittest plugin)**

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --version 0.4.4
helm unittest universal-chart/ --strict --file 'tests/*.yaml'
```

Expected output:
```
### Chart [ universal-chart ] universal-chart

 PASS  deployment    universal-chart/tests/deployment_test.yaml
 PASS  service       universal-chart/tests/service_test.yaml
 PASS  externalsecret universal-chart/tests/externalsecret_test.yaml
 PASS  clusterissuer  universal-chart/tests/clusterissuer_test.yaml
 PASS  httproute      universal-chart/tests/httproute_test.yaml

Charts:      1 passed, 1 total
Test Suites: 5 passed, 5 total
Tests:       6 passed, 6 total
```

**Step 7: Commit**

```bash
git add universal-chart/tests/
git commit -m "test: add helm-unittest suites for deployment, service, externalsecret, clusterissuer, httproute"
```

---

### Task 3: Add helm-docs and generate README

**Files:**
- Modify: `universal-chart/values.yaml` (add `# --` doc comments to top-level keys)
- Create: `universal-chart/README.md` (generated by helm-docs)
- Create: `.github/workflows/docs.yaml`

helm-docs reads `# --` prefixed comments immediately above a key in `values.yaml` and generates a `README.md` with a values table. The `# --` comment becomes the description column.

**Step 1: Add doc comments to the top-level keys in `universal-chart/values.yaml`**

Add `# -- description` immediately above each top-level key. Minimal viable annotations for the most-used keys:

```yaml
# -- Global settings applied to all workload templates (labels, annotations, affinity, etc.)
generic:
  labels: {}
  ...

# -- Pod affinity preset. Allowed values: `soft`, `hard`, `nil`
podAffinityPreset: soft

# -- Pod anti-affinity preset. Allowed values: `soft`, `hard`, `nil`
podAntiAffinityPreset: soft

# -- Node affinity preset configuration
nodeAffinityPreset:
  # -- Node affinity type. Allowed values: `soft`, `hard`
  type: ""
  # -- Node label key to match
  key: ""
  # -- Node label values to match
  values: []

# -- Prefix prepended to all resource names. Set to `"-"` to disable.
releasePrefix: ""

# -- Non-secret environment variables injected via ConfigMap envFrom. Use `--set "envs.KEY=value"`
envs: {}

# -- Non-secret environment variables as a raw YAML string (for multiline / special chars)
envsString: ""

# -- Secret environment variables injected via Secret envFrom. Use `--set "secretEnvs.KEY=value"`
secretEnvs: {}

# -- Secret environment variables as a raw YAML string
secretEnvsString: ""
```

Continue annotating `deployments`, `services`, `externalSecrets`, `clusterIssuers`, etc. at minimum with a one-liner.

**Step 2: Install helm-docs and generate README**

```bash
# macOS
brew install helm-docs

# or download binary
curl -sLO https://github.com/norwoodj/helm-docs/releases/download/v1.13.1/helm-docs_1.13.1_Darwin_x86_64.tar.gz
tar -xzf helm-docs_1.13.1_Darwin_x86_64.tar.gz helm-docs
sudo mv helm-docs /usr/local/bin/
```

Run:
```bash
helm-docs --chart-search-root universal-chart/
```

This creates `universal-chart/README.md`.

**Step 3: Create `.github/workflows/docs.yaml`**

```yaml
name: Update Docs

on:
  push:
    branches:
      - main

jobs:
  helm-docs:
    if: github.actor != 'github-actions[bot]'
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Install helm-docs
        run: |
          curl -sLO https://github.com/norwoodj/helm-docs/releases/download/v1.13.1/helm-docs_1.13.1_Linux_x86_64.tar.gz
          tar -xzf helm-docs_1.13.1_Linux_x86_64.tar.gz helm-docs
          sudo mv helm-docs /usr/local/bin/

      - name: Run helm-docs
        run: helm-docs --chart-search-root universal-chart/

      - name: Commit updated README if changed
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          if git diff --exit-code universal-chart/README.md; then
            echo "README.md is up to date, nothing to commit"
          else
            git add universal-chart/README.md
            git commit -m "docs: update helm-docs README [skip ci]"
            git push
          fi
```

**Step 4: Commit everything**

```bash
git add universal-chart/values.yaml universal-chart/README.md .github/workflows/docs.yaml
git commit -m "docs: add helm-docs annotations, generate README, add docs workflow"
```

---

### Task 4: Push to main and verify all jobs pass

**Step 1: Push**

```bash
git push upstream main
```

**Step 2: Watch the CI run**

```bash
gh run watch --repo OrigoSoftwareSolutions/universal-chart
```

Expected: All jobs green — `lint`, `unittest`, `security`, `release`. The `docs-check` job only runs on PRs so won't appear here.

**Step 3: Verify the OCI package was pushed**

```bash
gh api "orgs/OrigoSoftwareSolutions/packages/container/universal-chart" --jq '{name: .name, updated_at: .updated_at}'
```

Expected: `updated_at` timestamp matches the run.

**Step 4: Verify helm-docs auto-commit (if README changed)**

Check if `docs.yaml` workflow committed an updated README:

```bash
git log upstream/main --oneline -3
```

---

## Local Developer Workflow

After this is in place, developers need these tools locally:

```bash
# Lint
helm lint universal-chart/ --strict

# Unit tests
helm plugin install https://github.com/helm-unittest/helm-unittest --version 0.4.4
helm unittest universal-chart/ --strict --file 'tests/*.yaml'

# Docs (must run before pushing if values.yaml changed)
brew install helm-docs
helm-docs --chart-search-root universal-chart/
```
