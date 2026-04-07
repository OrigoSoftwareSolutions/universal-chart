# AGENTS.md — Origo Universal Helm Chart

Guidance for agentic coding assistants. Chart source lives in `universal-chart/`.

## Commands

```bash
# Lint (CI runs both on every PR)
helm lint universal-chart/ --strict
ct lint --config ct.yaml

# Render templates (smoke test)
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml
# With Istio CRD resolution:
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  --api-versions networking.istio.io/v1beta1

# Unit tests — all suites
helm unittest universal-chart/ --strict --file 'tests/*.yaml'
# Single suite (match exact filename incl. extension)
helm unittest universal-chart/ --strict --file 'tests/deployment_test.yaml'

# Schema validation
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.33.6 \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# Docs — regenerate after any values.yaml change (CI enforces via git diff)
helm-docs --chart-search-root universal-chart/ -o ../README.md

# Format
helmfmt universal-chart/
pre-commit run --all-files
```

**Verification before declaring done**: `helm lint --strict` + `helm unittest --strict` must pass. If values.yaml changed, regenerate README.md.

## Repository Layout

```
universal-chart/
  Chart.yaml, values.yaml, values.schema.json
  ci/test-values.yaml           ← CI smoke-test values
  templates/
    helpers/_*.tpl              ← named template partials
    *.yml (nixys originals)     ← .yml = nixys, .yaml = Origo-added
    *.yaml (Origo additions)
  tests/*_test.yaml             ← helm-unittest suites
.helmfmt                        ← 2-space indent, all extensions
.yamllint                       ← max 150 chars, 2-space indent
.pre-commit-config.yaml         ← helmfmt + helm-docs hooks
ct.yaml                         ← chart-testing config
```

## YAML / Formatting Style

Enforced by `.yamllint` and `.helmfmt`:
- **Indent**: 2 spaces — no tabs
- **Line length**: max 150 characters
- **Booleans**: `true`/`false` only (never `yes`/`no`/`on`/`off`)
- **No trailing spaces**; max 3 consecutive empty lines
- **`nindent`** value must match actual rendered indentation level
- **Whitespace stripping**: `{{-` / `-}}` in helpers; plain `{{`/`}}` where leading newline is intentional
- Quote image tags that look numeric: `imageTag: "1.25"`

## Template Authoring

### Core resource skeleton

```yaml
{{- $general := $.Values.<kind>sGeneral -}}
{{- range $name, $val := .Values.<kind>s }}
  {{- if not ($val.disabled | default false) }}
---
apiVersion: ...
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

**Key rules**:
- `---` goes **inside** range, **after** disabled guard
- Names via `helpers.app.fullname` — never manual construction
- Cluster-scoped resources omit `namespace:`
- CRD specs use thin passthrough: `{{- toYaml $val.spec | nindent 2 }}`
- User-provided values go through `helpers.tplvalues.render`
- Three-level merge (workloads): instance → `*General` → `defaults` → hardcoded fallback, using `dig`

### Template categories

| Category | Examples | Pattern |
|---|---|---|
| **Workload** | deployment, statefulset, cronjob, job, hooks | Full pattern: `$general`, `range`, disabled guard, `helpers.pod`, three-level merge, `tplvalues.render` |
| **CRD / simple** | ExternalSecret, HTTPRoute, ClusterIssuer | Thin passthrough, no `$general`, no merge: `toYaml $val.spec` |
| **Legacy nixys** (3 files) | istiogateway.yml, istiodestinationrule.yml, istiovirtualservice.yml | Have disabled guard but use `$gateway.name \| default $host` naming convention and inline spec fields (not thin passthrough). Follow their existing style — do NOT refactor |

### Named template conventions

All in `templates/helpers/_*.tpl`. Always `{{- define "helpers.x.y" -}}...{{- end -}}`.

| Namespace | Key helpers |
|---|---|
| `helpers.app.*` | `fullname`, `labels`, `selectorLabels`, `defaultAnnotations` |
| `helpers.pod` | Full pod spec (~110 lines) — used by ALL workloads |
| `helpers.capabilities.*` | `<kind>.apiVersion` — semver-based resolution |
| `helpers.volumes.*` | `typed`, `renderVolume`, `renderVolumeMount` |
| `helpers.workload.*` | `resolveResources`, `healthCheckProbe`, `singleContainerPorts`, `envs`, `checksum` |
| `helpers.container.*` | `render` — single-container rendering, shorthand expansion |
| `helpers.deprecation.*` | Deprecation notices for renamed/removed options |
| `helpers.tplvalues.render` | Evaluate `{{ }}` expressions inside user values |

**`_pod.tpl` changes affect ALL workloads** — test with deployment, statefulset, cronjob, and hook values.

### Checklist for new templates

1. Plural values key (`foos`), optional `foosGeneral`
2. Disabled guard inside `range`, `---` after guard
3. `helpers.app.fullname` for names
4. `namespace: {{ $.Release.Namespace }}` (unless cluster-scoped)
5. `helpers.app.labels` / `selectorLabels` for labels
6. `tplvalues.render` on all user-provided string/map values
7. Matching test suite in `tests/<resource>_test.yaml`

## Testing Conventions

```yaml
suite: <descriptive name>
templates:
  - <template-file>.yml   # exact filename incl. extension!
tests:
  - it: <lowercase sentence>
    set:
      <pluralKind>.<instance>.<field>: <value>
    asserts:
      - <assertion>
```

- First test: `isKind` + `apiVersion`
- Namespaced → `isNotEmpty: path: metadata.namespace`; cluster-scoped → `notExists: path: metadata.namespace`
- Disabled flag → `hasDocuments: count: 0`
- Use `set:` with minimal values — provide at minimum a container image
- Multi-document: use `documentIndex` to target specific instance
- **Wrong extension** (`.yaml` vs `.yml`) → suite silently finds 0 documents

## CI Pipeline (PRs to main)

Five parallel jobs: `lint` (helm lint + kubeconform), `unittest`, `security` (Trivy scan), `ct-lint`, `docs-check` (README.md freshness).

## Release Process

Bump `version:` in `universal-chart/Chart.yaml` → push to `main` → GitHub Actions packages and pushes to `oci://ghcr.io/origosoftwaresolutions/universal-chart`. No manual tagging, no gh-pages, OCI-native only.

## What NOT to Do

- Do not add Traefik, VictoriaMetrics VMServiceScrape, or SealedSecrets (deliberately removed)
- Do not add abstraction layers on CRD `spec:` blocks — use `toYaml` passthrough
- Do not run `helm upgrade` or `kubectl apply` — this repo is chart source only
- Do not skip `helm lint --strict` or unit tests before declaring done
- Do not commit with `README.md` out of date
