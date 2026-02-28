# Global Development Standards

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately – don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One tack per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes – don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests – then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management
1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.


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

```bash
# Lint (runs in CI on every push)
helm lint universal-chart/ --strict
ct lint --config ct.yaml          # PR only, requires ct CLI

# Render all resources with CI test values
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml
# With Istio API resolution:
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  --api-versions networking.istio.io/v1beta1

# Unit tests (helm-unittest plugin)
helm unittest universal-chart/ --strict --file 'tests/*.yaml'
helm unittest universal-chart/ --strict --file 'tests/deployment_test.yaml'  # single suite

# Schema validation (kubeconform)
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.33.6 \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# Docs — regenerate after any values.yaml change (CI enforces via git diff)
helm-docs --chart-search-root universal-chart/ -o ../README.md

# Formatting
helmfmt universal-chart/
pre-commit run --all-files         # runs helmfmt + helm-docs hooks
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
- **Legacy nixys templates** (3 Istio files: `istiogateway.yml`, `istiodestinationrule.yml`, `istiovirtualservice.yml`) deviate from core pattern — no disabled guard, `---` outside conditional, inline spec logic. See *Template Categories* below.

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

| Pattern                    | Example                                                                  |
| -------------------------- | ------------------------------------------------------------------------ |
| `helpers.app.*`            | `helpers.app.fullname`, `helpers.app.labels`                             |
| `helpers.capabilities.*`   | `helpers.capabilities.cronJob.apiVersion`                                |
| `helpers.pod`              | Shared pod spec — used by all workload types                             |
| `helpers.volumes.*`        | `helpers.volumes.typed`, `helpers.volumes.renderVolume`                  |
| `helpers.workload.*`       | `helpers.workload.resolveResources`, `helpers.workload.healthCheckProbe` |
| `helpers.tplvalues.render` | Evaluate template expressions inside values                              |

Always use `{{- define "helpers.x.y" -}}...{{- end -}}` (strip-whitespace delimiters) for helper templates.

### Template categories

**Workload templates** (Deployment, StatefulSet, CronJob, Job, Hook) — full core pattern with `$general`, `range`, disabled guard, `helpers.pod` for shared pod spec, three-level merge via `dig`, labels/annotations merge via `tplvalues.render`, `defaultAnnotations` for checksum annotations.

**CRD / simple templates** (ExternalSecret, SecretStore, ClusterIssuer, HTTPRoute, etc.) — thin passthrough, no `$general`, no merge logic: `{{- toYaml $val.spec | nindent 2 }}`.

**Legacy nixys templates** (3 files): `istiogateway.yml`, `istiodestinationrule.yml`, `istiovirtualservice.yml` — inherited from upstream. Deviations:
- No `disabled` guard — cannot be individually suppressed
- `---` placed outside conditional (directly after `range`)
- `istiovirtualservice.yml` has inline spec logic instead of `toYaml` passthrough
- When modifying: follow their existing style. Do NOT refactor to passthrough without explicit request

Newer Origo Istio templates (`istiopeerauthentications.yaml`, `istioauthorizationpolicies.yaml`) DO follow core pattern.

**Templates without disabled guard** (besides legacy Istio): `configmap.yml`, `secret.yml`, `pvc.yml`, `servicemonitor.yml`, `serviceaccount.yml`, `extra.yml`, `helm-hooks.yml`. These use other conditionals or always render. New templates MUST include the disabled guard.

**File naming**: `.yml` = original nixys, `.yaml` = Origo-added. No functional difference.

### Checklist for new templates

1. Plural values key: `foos` (map of instances), optional `foosGeneral` (shared defaults)
2. Disabled guard inside `range`, `---` after guard
3. `helpers.app.fullname` for name — never manual
4. `namespace: {{ $.Release.Namespace }}` — unless cluster-scoped
5. `helpers.app.labels` or `helpers.app.selectorLabels` for labels
6. `tplvalues.render` on all user-provided string/map values
7. Matching test suite in `tests/<resource>_test.yaml`

---

## Helper Templates (`templates/helpers/`)

All files are `_*.tpl`. Every define uses strip-whitespace: `{{- define "helpers.x.y" -}}...{{- end -}}`.

| File                            | Defines                                                                                        | Used by                             |
| ------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------- |
| `_app.tpl`                      | `fullname`, `labels`, `selectorLabels`, `defaultAnnotations`, `chart`                          | Every template                      |
| `_pod.tpl` (230 lines)          | `helpers.pod` — full pod spec                                                                  | Workload templates only             |
| `_capabilities.tpl` (168 lines) | `helpers.capabilities.<kind>.apiVersion`                                                       | Templates needing semver apiVersion |
| `_volumes.tpl`                  | `helpers.volumes.typed`, `renderVolume`, `renderVolumeMount`                                   | `_pod.tpl`                          |
| `_workloads.tpl`                | `envs`, `envsFrom`, `checksum`, `singleContainerPorts`, `resolveResources`, `healthCheckProbe` | `_pod.tpl`, workload templates      |
| `_tplvalues.tpl`                | `helpers.tplvalues.render`                                                                     | Everywhere user values are rendered |
| `_configmaps.tpl`               | `includeEnv`, `includeEnvConfigmap`, `embedConfigmapData`                                      | `_workloads.tpl`, `configmap.yml`   |
| `_secrets.tpl`                  | `includeEnv`, `includeEnvSecret`, `embedSecretData`                                            | `_workloads.tpl`, `secret.yml`      |
| `_affinities.tpl`               | `helpers.affinities.nodes`, `helpers.affinities.pods`                                          | `_pod.tpl`                          |
| `_deprecations.tpl`             | Deprecation warnings                                                                           | Chart-level                         |

### `_pod.tpl` — central pod spec

Largest helper (230 lines). Generates the entire `pod.spec` block consumed by all workloads.

**Call signature**: `(dict "value" . "general" $general "name" $name "extraLabels" .extraSelectorLabels "context" $)`

**Merge priority** (instance wins): instance field → `$general` field → `$.Values.defaults.*` → hardcoded fallback.

**Single-container shorthand** (handled inside `_pod.tpl`):
- If `.image` is set (no `.containers` list), synthesizes a single container from workload-level fields
- `.ports` map → `helpers.workload.singleContainerPorts` → containerPorts list
- `.resources` string → `helpers.workload.resolveResources` → preset expansion (nano/small/medium/large/xlarge)
- `.healthCheck` → `helpers.workload.healthCheckProbe` → liveness + readiness + startup (default: HTTP GET `/healthz:8080`, period `10s`)

### Helper editing rules

- `_pod.tpl` changes affect ALL workloads — test with deployment, statefulset, cronjob, and hook values.
- Dict parameters MUST match existing call signatures — callers pass specific keys.
- `tplvalues.render` must wrap any field that could contain `{{ }}` expressions.
- New helpers: follow `helpers.<domain>.<function>` naming. Never define at top-level namespace.

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

Test files: `universal-chart/tests/*_test.yaml`. Run: `helm unittest universal-chart/ --strict --file 'tests/*.yaml'`.

### Assert conventions

- First test: assert `isKind` + `apiVersion`.
- Namespaced → `isNotEmpty: path: metadata.namespace`; cluster-scoped → `notExists: path: metadata.namespace`.
- Test disabled flag: `hasDocuments: count: 0`.
- Use `set:` with minimal targeted values — don't load full values files.

### Test structure

```yaml
suite: <descriptive name>
templates:
  - <template-file>.yml   # must match exact filename including extension
tests:
  - it: <lowercase sentence describing expectation>
    set:
      <pluralKind>.<instanceName>.<field>: <value>
    asserts:
      - <assertion>
```

### Workload shorthand tests

Shorthand fields resolve inside `_pod.tpl` — the test still targets the parent template (e.g. `deployment.yml`). Resource preset tests: set `deployments.<name>.resources: small` and assert expanded CPU/memory values.

### Common test mistakes

- Wrong template extension (`deployment.yaml` vs `deployment.yml`) → suite silently finds 0 documents.
- Missing required fields → template fails to render. Provide at minimum: container image.
- Cluster-scoped CRDs: assert `notExists: path: metadata.namespace`, not `equal: ... ""`.
- Multi-document templates: use `documentIndex` to target specific instance when setting multiple values keys.

---

## Release Process

1. Bump `version:` in `universal-chart/Chart.yaml`.
2. Run `helm-docs --chart-search-root universal-chart/ -o ../README.md` and commit the updated `README.md`.
3. Push to `main` — GitHub Actions automatically packages and pushes to `oci://ghcr.io/origosoftwaresolutions/universal-chart`.

**Do not** manually tag, maintain a `gh-pages` branch, or manage a `Chart.yaml` index — distribution is OCI-native only.

---

## What NOT to Do

- Do not add Traefik, VictoriaMetrics `VMServiceScrape`, or SealedSecrets — these were deliberately stripped from the nixys upstream.
- Do not add abstraction layers on top of CRD `spec:` blocks — use `toYaml` passthrough.
- Do not run `helm upgrade` or `kubectl apply/delete` — this repo is chart source only.
- Do not skip `helm lint --strict` or unit tests before declaring a change complete.
- Do not commit with `README.md` out of date — CI will fail the `docs-check` job.
