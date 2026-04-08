# Changelog

All notable changes to the Origo Universal Helm Chart are documented here.

Format: [Semantic Versioning](https://semver.org). Dates are approximate (branch audit session).

---

## [1.5.6] — 2026-04-08

### Fixed

#### `concurrencyPolicy` not passed through on CronJob (B1)
CronJobs support a `concurrencyPolicy` field (`Allow`, `Forbid`, `Replace`)
but the template only exposed the boolean shorthand `singleOnly: true`
(`Forbid`). Explicit `concurrencyPolicy` values were silently ignored.

`concurrencyPolicy` now cascades instance → `cronJobsGeneral` → `defaults`
with a nil-sentinel pattern. `singleOnly: true` continues to work as a
`Forbid` shorthand. The field is omitted entirely when not set at any tier.

Schema: `concurrencyPolicy` enum added to `$defs.cronJob`, `$defs.workload`,
and `$defs.workloadGeneral`.

#### PDB renders a no-op resource when neither budget field is set (B2)
A PDB without `minAvailable` or `maxUnavailable` produced a resource with
an empty `spec:` — valid YAML, accepted by the API server, but completely
ineffective as a disruption budget. Now fails at render time with an
actionable error message rather than silently creating a useless resource.

#### `progressDeadlineSeconds: 600` always emitted on Deployments (B3)
The Deployment template fell back to `600` when `progressDeadlineSeconds`
was unset, meaning the value appeared in rendered manifests even when the
user never configured it. This prevented Kubernetes from applying its own
default and created noise in `helm diff` output.

The key is now emitted only when explicitly set at instance, `*General`,
or `defaults` tier; otherwise it is omitted and Kubernetes owns the default.

#### Empty affinity preset renders `podAffinity: {}` / `podAntiAffinity: {}` (B4)
Setting `podAffinityPreset: ""` or `podAntiAffinityPreset: ""` to disable
the preset caused `helpers.affinities.pods` to return `{}`. The pod spec
then contained empty affinity sub-objects that strict admission webhooks
reject and that confuse operators expecting the preset to be disabled.

`helpers.affinities.nodes` and `helpers.affinities.pods` now return an
empty string instead of `{}` when the preset type is empty. `_pod.tpl`
gates `nodeAffinity`, `podAffinity`, and `podAntiAffinity` with
string-trim guards so empty results are omitted entirely.

#### `unhealthyPodEvictionPolicy` not gated by Kubernetes version (F1)
`unhealthyPodEvictionPolicy` is a GA field only in Kubernetes ≥ 1.27.
The template emitted it unconditionally, causing schema validation failures
on clusters running older versions.

The field is now gated with `semverCompare ">=1.27-0" $.Capabilities.KubeVersion.GitVersion`
and omitted on older clusters.

#### `suspend: false` always emitted on CronJob (F2)
`suspend: false` was always rendered regardless of whether it was set,
cluttering manifests and making it impossible to distinguish
"explicitly not suspended" from "not configured". The key is now omitted
when not explicitly set at any tier.

#### `defaults.securityContext` alias ignored at defaults tier (F3)
`podSecurityContext` and `securityContext` are accepted as aliases at
the instance and `*General` tiers, but only `podSecurityContext` was
checked at the `defaults` tier. `defaults.securityContext` was silently
ignored, breaking the documented alias.

`defaults.securityContext` is now honoured as a fallback when
`defaults.podSecurityContext` is not set.

#### Schema gaps rejected valid configurations (S1–S3)
Several fields were functional in templates but absent from the JSON schema,
causing `helm lint --strict` to reject valid user configurations:

- **S1:** `defaults.revisionHistoryLimit` — added to `defaults` properties
- **S2:** `defaults.dnsConfig` — added to `defaults` properties
- **S3:** `workloadGeneral` missing: `restartPolicy`, `commandDurationAlert`,
  `podManagementPolicy`, `lifecycle`, `startupProbe`, `livenessProbe`,
  `readinessProbe`, `healthCheck`, `concurrencyPolicy`

#### `immutable` field not supported on ConfigMap and Secret (S5)
Kubernetes supports `immutable: true` on ConfigMaps and Secrets to prevent
data mutation after creation. The chart did not pass this field through,
forcing users to use `extraDeploy` as a workaround.

Both `configmap.yaml` and `secret.yaml` now emit `immutable:` when set.
The field is added to the Secret schema (`$defs.secret`).

#### VirtualService http route emits `name: ""` when name not set (M3)
Istio VirtualService http routes had `name:` always emitted, rendering as
`name: ""` when no name was configured. The Istio API rejects empty-string
route names on some versions. The `name:` key is now only emitted when
explicitly set.

#### DestinationRule always emits `trafficPolicy: {}` (M4)
When no `trafficPolicy` was configured, DestinationRule emitted
`trafficPolicy: {}`, which is semantically a no-op but may trigger Istio
validation warnings and causes unnecessary diff noise. The key is now only
emitted when the value is non-empty.

### Tests

490 tests passing (up from 477 in 1.5.5). New and updated suites:

- `cronjob_test.yaml` — B1 (concurrencyPolicy), F2 (suspend nil-guard)
- `general_merge_test.yaml` — B3 (progressDeadlineSeconds), B4 (empty affinity), F3 (securityContext alias)
- `pdb_test.yaml` — F1 (version-gated unhealthyPodEvictionPolicy)
- `secret_test.yaml` — S5 (immutable passthrough)
- `istiovirtualservice_test.yaml` — M3 (name nil-guard)
- `istiodestinationrule_test.yaml` — M4 (trafficPolicy nil-guard)

---

## [1.5.5] — 2026-04-08

### Fixed

#### HPA renders invalid YAML when no metrics are configured
`hpa.yaml` unconditionally emitted a `metrics:` key even when neither
`targetCPU`, `targetMemory`, nor custom `metrics` were set, producing an
empty YAML scalar that the Kubernetes API server rejects. The `metrics:`
block is now only emitted when at least one metric is configured.

**Before:** Any HPA relying solely on custom `.metrics:` would silently
fail at apply time. HPAs with no scaling targets would emit broken YAML.

**After:** `metrics:` key is omitted entirely when no metrics are
configured. CPU, memory, and custom metric paths all work unchanged.

#### Missing pod spec fields blocked by `additionalProperties: false`
The workload schema had `additionalProperties: false` but was missing
several standard Kubernetes pod spec fields, causing `helm lint` to reject
valid configurations with "additional properties not allowed":

| Field | Use case |
|---|---|
| `runtimeClassName` | gVisor, Kata Containers, WebAssembly runtimes |
| `automountServiceAccountToken` | Per-pod override of SA-level token mount default |
| `overhead` | RuntimeClass resource overhead accounting |
| `readinessGates` | Custom pod readiness conditions |
| `schedulingGates` | Gate pods before they enter the scheduling queue |
| `os` | Windows/Linux OS constraint on mixed-OS clusters |

All six fields are now present in both `workload` and `workloadGeneral`
schemas, and `_pod.tpl` renders them all with correct cascade semantics
(instance → general → defaults where applicable).

#### Hook `deletePolicy` default destroyed logs on failure
The default `deletePolicy: before-hook-creation` deleted the hook Job
before execution. When a hook failed, the pod was already gone — making
`kubectl logs` impossible and post-mortem debugging very painful.

**New default:** `before-hook-creation,hook-succeeded`
- Deletes the stale Job from the *previous run* before starting a new one
  (prevents accumulation, same as before)
- Keeps the failed Job and its pods around for `kubectl logs` inspection
- Automatically cleans up on success

**Migration:** If you relied on `before-hook-creation` behaviour
explicitly (e.g. you want cleanup on both success and failure), set
`deletePolicy: before-hook-creation` on the hook instance or via
`hooksGeneral.deletePolicy`.

#### `hooksGeneral.deletePolicy` (and `kind`/`weight`) silently ignored
`hooksGeneral.deletePolicy`, `hooksGeneral.kind`, and `hooksGeneral.weight`
were not in the `workloadGeneral` schema, so setting them caused a schema
validation error. Additionally, `deletePolicy` was not read from
`hooksGeneral` in the template — it was hard-coded to the fallback.

Both issues are now fixed: the fields are in the schema and the template
resolves them via the standard instance → hooksGeneral → chart default
cascade, consistent with all other cascadable fields.

---

## [1.5.4] — 2026-04-08

### Fixed

#### `envsFromSecret` / `envsFromConfigmap` cherry-pick completely non-functional
The `helpers.secrets.includeEnv` and `helpers.configmaps.includeEnv`
helpers were rewritten. The old implementation expected
`{secretName: [keys]}` format but the documented and README-described API
is `{ENV_VAR_NAME: {name: secretName, key: keyName}}`. Any user of the
cherry-pick form was silently injecting no env vars.

**Before:**
```yaml
# Old (broken) format
envsFromSecret:
  my-secret:
    - DB_PASSWORD
```

**After (correct documented format):**
```yaml
envsFromSecret:
  DB_PASSWORD:
    name: my-secret
    key: password
```

New test suite `tests/envsfrom_cherry_pick_test.yaml` covers both helpers
with direct and via-general cascade paths.

---

## [1.5.3] — 2026-04-08

### Added
- `hostNetwork`, `hostPID`, `hostIPC`, `shareProcessNamespace` pod spec
  fields with full 3-tier cascade (instance → `*General` → `defaults`)
  and schema validation in both `workload` and `workloadGeneral`.

### Fixed
- **PDB duplicate selector labels** — `pdb.yaml` injected
  `defaults.extraSelectorLabels` twice: once via the
  `helpers.app.workloadSelectorLabels` helper chain and once explicitly
  on line 30. When `defaults.extraSelectorLabels` was non-empty this
  produced a duplicate YAML key, rendering the PDB invalid.
- **Secrets `stringData`** — `secret.yaml` only supported `data:` (base64
  values). Added `stringData:` passthrough for plain-text secret values,
  useful for secrets managed by operators that expect unencoded input.

---

## [1.5.2] — 2026-04-07

### Fixed
- **`preStopSleep` cascade** — the preStop sleep injection only read
  `defaults.preStopSleep`; instance-level and `*General`-level values
  were silently ignored. Full 3-tier cascade is now implemented.
  Schema updated: `preStopSleep` added to `workload` and `workloadGeneral`.
- **`publishNotReadyAddresses: false` silently dropped** in auto-generated
  Services. The field was only emitted when truthy; `false` is a valid
  value and is now rendered correctly.
- **`revisionHistoryLimit: 0` and `minReadySeconds: 0` silently dropped** —
  the template used `{{- if .field }}` guards which evaluate `0` as falsy.
  Both fields now use explicit nil checks.
- **Schema gaps** — `minReadySeconds`, `extraImagePullSecrets`, and
  `preStopSleep` added to `workloadGeneral` schema.

---

## [1.5.1] — 2026-04-07

### Fixed
- **`defaults.revisionHistoryLimit` not applied** to Deployments and
  StatefulSets. The field existed in `defaults` but was never read in
  templates. DaemonSets do not support this field and are excluded.
- **`automountServiceAccountToken` defaults to `false`** on
  ServiceAccount resources. The Kubernetes default (`true`) silently
  mounts a token into every pod even when the workload never uses the
  API server.
- **`allocateLoadBalancerNodePorts` passthrough** in auto-generated
  Services. The field was being dropped instead of passed through.

---

## [1.5.0] — 2026-04-07

### Fixed
- **HPA `minReplicas`/`maxReplicas` rendered as strings** — the template
  used `{{ .minReplicas | default 2 }}` which yields a string when the
  value comes from `--set`. Both fields now pipe through `| int`.
- **`imagePullSecrets` deduplication** — workload-level and global pull
  secrets were concatenated without deduplication; a secret appearing in
  both `imagePullSecrets` (global) and `extraImagePullSecrets` (workload)
  caused duplicate entries in the pod spec. Now deduped via `| uniq`.
- **`dnsConfig` not cascaded** — `dnsConfig` was only read at the instance
  level; `*General` and `defaults` values were silently ignored. Full
  3-tier cascade now implemented. `dnsConfig` added to `workloadGeneral`
  schema.
- **Various auto-Service field passthrough fixes** — `clusterIP`,
  `loadBalancerIP`, `loadBalancerSourceRanges`, `externalTrafficPolicy`,
  `sessionAffinity`, `sessionAffinityConfig`, `healthCheckNodePort`,
  `ipFamilies`, `ipFamilyPolicy` were not passed through to auto-generated
  Services.
- **Service selector defaults** — standalone Services now default the
  selector to the service key name when `workload:` is omitted, and
  support an explicit `selector:` override.
- **Typed volumes** — `configMapName`, `secretName`, `claimName` fields
  were not correctly resolved in typed volume specs.
- **`healthCheck.scheme` and `healthCheck.successThreshold`** — both
  were silently dropped from generated probes.
- **DaemonSets excluded from HPA target kinds** — DaemonSets are not
  scalable; the schema now rejects HPAs targeting DaemonSets.
- **`containers[]` and `initContainers[]` entries require `image`** —
  the schema now enforces that explicit container entries carry an image
  (workload-level shorthand default does not apply to list form).

---

## Upgrade Notes

### 1.5.4 → 1.5.5

**Breaking (behaviour change):** The default `helm.sh/hook-delete-policy`
annotation on Helm hooks changes from `before-hook-creation` to
`before-hook-creation,hook-succeeded`.

- Hooks that succeeded previously: behaviour unchanged (Job is deleted
  after the hook completes).
- Hooks that **failed** previously: the Job and pod are now **retained**
  after failure instead of being deleted. This means failed hook pods
  will accumulate if you never clean them up. Either:
  - Clean them up manually: `kubectl delete jobs -l helm.sh/chart=...`
  - Opt back in to the old behaviour per-hook:
    `deletePolicy: before-hook-creation`
  - Or set it globally: `hooksGeneral.deletePolicy: before-hook-creation`

### 1.5.3 → 1.5.4

No breaking changes. The cherry-pick `envsFromSecret`/`envsFromConfigmap`
fix is technically a breaking change only for users who were relying on
the (broken) old format — but since the old format produced no env vars,
any working deployment would have already migrated to inline `env:`.

### Any → 1.5.x

No values key renames. All new keys are additive. Existing values files
will continue to work.
