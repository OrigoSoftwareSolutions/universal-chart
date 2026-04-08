# Changelog

All notable changes to the Origo Universal Helm Chart are documented here.

Format: [Semantic Versioning](https://semver.org). Dates are approximate (branch audit session).

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
