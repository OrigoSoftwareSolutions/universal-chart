# AGENTS.md — Origo Universal Helm Chart

Guidance for agentic coding assistants working in this repository.
The chart source lives in `universal-chart/`. All paths below are relative to repo root unless stated otherwise.

---

## Repository Layout

```
universal-chart/          ← Helm chart source
  Chart.yaml
  values.yaml
  values.schema.json
  ci/test-values.yaml     ← smoke-test values used by CI
  templates/
    helpers/              ← named template partials (_*.tpl)
    *.yml / *.yaml        ← one file per Kubernetes resource kind
  tests/                  ← helm-unittest test suites (*_test.yaml)
.helmfmt                  ← helmfmt formatter config (2-space indent)
.yamllint                 ← yamllint rules (max 150 chars, 2-space indent)
.pre-commit-config.yaml   ← helmfmt + helm-docs hooks
ct.yaml                   ← chart-testing config
```

---

## Commands

### Lint

```bash
# Strict Helm lint (runs in CI on every push)
helm lint universal-chart/ --strict

# chart-testing lint (PR only, requires ct CLI)
ct lint --config ct.yaml
```

### Render / Smoke Test

```bash
# Render all resources with CI test values
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml

# Render with live Istio API resolution
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  --api-versions networking.istio.io/v1beta1

# Inspect rendered kinds
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | grep "^kind:" | sort | uniq
```

### Unit Tests (helm-unittest)

```bash
# Install plugin once
helm plugin install https://github.com/helm-unittest/helm-unittest --version 1.0.3

# Run ALL tests
helm unittest universal-chart/ --strict --file 'tests/*.yaml'

# Run a SINGLE test suite (e.g. deployment tests only)
helm unittest universal-chart/ --strict --file 'tests/deployment_test.yaml'

# Run a specific suite by name pattern
helm unittest universal-chart/ --strict --file 'tests/workload_shorthand_test.yaml'
```

### Schema Validation

```bash
# Install kubeconform once: brew install kubeconform
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | kubeconform \
    -strict \
    -ignore-missing-schemas \
    -kubernetes-version 1.33.6 \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

### Docs (helm-docs)

```bash
# Install once: brew install helm-docs
helm-docs --chart-search-root universal-chart/

# Docs MUST be regenerated after any values.yaml change before pushing.
# CI enforces this on PRs via git diff --exit-code universal-chart/README.md.
```

### Formatting (helmfmt)

```bash
# Install once: pip install helmfmt  OR use the pre-commit hook
helmfmt universal-chart/

# Pre-commit hooks run helmfmt + helm-docs automatically on staged files
pre-commit run --all-files
```

---

## Template Authoring Guidelines

### Core resource pattern

Every resource template follows this exact skeleton — do not deviate:

```yaml
{{- $general := $.Values.<kind>sGeneral -}}
{{- range $name, $val := .Values.<kind>s }}
  {{- if not ($val.disabled | default false) }}
---
apiVersion: {{ include "helpers.capabilities.<kind>.apiVersion" $ }}
kind: <Kind>
metadata:
  name: {{ include "helpers.app.fullname" (dict "name" $name "context" $) }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "helpers.app.labels" $ | nindent 4 }}
spec:
  ...
  {{- end }}
{{- end }}
```

Key rules:
- `---` document separator goes **inside** the range, **after** the disabled guard.
- Resource names always use `helpers.app.fullname` — never construct names manually.
- Cluster-scoped resources (`ClusterSecretStore`, `ClusterExternalSecret`, `ClusterIssuer`) **omit** `namespace:`.
- CRD spec blocks use **thin passthrough** — `{{- toYaml $val.spec | nindent 2 }}` — no abstraction.

### Three-level value merging

For scalars in workloads: instance value → `*General` (e.g. `deploymentsGeneral`) → `generic` (global) → hardcoded default.
Use `dig` for safe nested reads:

```yaml
replicas: {{ dig "replicas" (dig "replicas" 1 $general) $d | int }}
```

### Template expressions in values

Wrap user-provided values through `helpers.tplvalues.render` so users can write `{{ .Release.Name }}-suffix` anywhere:

```yaml
{{- include "helpers.tplvalues.render" (dict "value" .someField "context" $) | nindent 4 }}
```

### apiVersion resolution

- Core k8s resources: use `helpers.capabilities.<kind>.apiVersion` (semver-based).
- Istio networking/security: use `.Capabilities.APIVersions.Has` with hardcoded `v1beta1` fallback.
- New CRDs with a stable single version: hardcode the version directly in the template.

### Named template conventions

| Pattern | Example |
|---|---|
| `helpers.app.*` | `helpers.app.fullname`, `helpers.app.labels` |
| `helpers.capabilities.*` | `helpers.capabilities.cronJob.apiVersion` |
| `helpers.pod` | Shared pod spec — used by all workload types |
| `helpers.volumes.*` | `helpers.volumes.typed`, `helpers.volumes.renderVolume` |
| `helpers.workload.*` | `helpers.workload.resolveResources`, `helpers.workload.healthCheckProbe` |
| `helpers.tplvalues.render` | Evaluate template expressions inside values |

Always use `{{- define "helpers.x.y" -}}...{{- end -}}` (strip-whitespace delimiters) for helper templates.

---

## YAML / Formatting Style

Rules enforced by `.yamllint` and `.helmfmt`:

- **Indent**: 2 spaces everywhere — no tabs.
- **Line length**: max 150 characters.
- **Boolean literals**: `true` / `false` only (never `yes`/`no`/`on`/`off`).
- **Trailing spaces**: not allowed.
- **Empty lines**: max 3 consecutive.
- **`nindent` value** must match the actual indentation level in the rendered output.
- Helm action delimiters: use `{{-` / `-}}` to strip surrounding whitespace in helpers; use plain `{{` / `}}` where a leading newline is intentional in output.
- Always quote image tags that could be parsed as numbers: `imageTag: "1.25"`.

---

## Testing Guidelines

### Writing a new test suite

Create `universal-chart/tests/<resource>_test.yaml`. Follow this structure:

```yaml
suite: <resource name>
templates:
  - <template-file>.yaml   # or .yml
tests:
  - it: renders correct kind and apiVersion
    set:
      <values path>: <value>
    asserts:
      - isKind:
          of: <Kind>
      - equal:
          path: apiVersion
          value: <expected>
```

### Assert conventions

- Always test `isKind` and `apiVersion` in the first test of a suite.
- For namespaced resources, assert `isNotEmpty: path: metadata.namespace`.
- For cluster-scoped resources, assert `notExists: path: metadata.namespace`.
- Test the `disabled: true` flag with `hasDocuments: count: 0`.
- Use `set:` for minimal targeted values — don't load full values files unless needed.

---

## Release Process

1. Bump `version:` in `universal-chart/Chart.yaml`.
2. Run `helm-docs --chart-search-root universal-chart/` and commit the updated `README.md`.
3. Push to `main` — GitHub Actions automatically packages and pushes to `oci://ghcr.io/origosoftwaresolutions/universal-chart`.

**Do not** manually tag, maintain a `gh-pages` branch, or manage a `Chart.yaml` index — distribution is OCI-native only.

---

## What NOT to Do

- Do not add Traefik, VictoriaMetrics `VMServiceScrape`, or SealedSecrets — these were deliberately stripped from the nixys upstream.
- Do not add abstraction layers on top of CRD `spec:` blocks — use `toYaml` passthrough.
- Do not run `helm upgrade` or `kubectl apply/delete` — this repo is chart source only.
- Do not skip `helm lint --strict` or unit tests before declaring a change complete.
- Do not commit with `README.md` out of date — CI will fail the `docs-check` job.
