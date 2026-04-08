# Universal Chart — Known Issues

This file is the canonical register of confirmed chart issues. Each entry has a
severity, exact file + line reference, and a recommended fix. Issues are resolved
in `universal-chart/CHANGELOG.md` when fixed.

Generated after the exhaustive 11-agent parallel audit of v1.5.5.

---

## Legend

| Severity | Meaning |
|---|---|
| 🔴 Bug | Broken behavior — breaks rendering or produces invalid Kubernetes objects |
| 🟡 Footgun | Won't break today, will cause silent failures or operational pain |
| 🔵 Schema gap | helm lint or helm install rejects valid user configuration |
| ⚪ Minor/Polish | Noisy output, inconsistency, or wasted work |

---

## 🔴 Bugs

### B1 — `concurrencyPolicy` not passthrough-able on CronJob

**Status**: Fixed in 1.5.6
**File**: `templates/cronjob.yaml` lines 16–18  
**File**: `values.schema.json` `$defs.cronJob`

**Problem**: Only `singleOnly: true` → `Forbid` is supported. The values `Replace`
and explicit `Allow` are unreachable. Users cannot override the default `Allow`
policy or use `Replace` semantics.

**Fix**: Add `concurrencyPolicy` to schema. In `cronjob.yaml`: emit `concurrencyPolicy`
if set, else if `singleOnly` emit `Forbid`, else omit entirely.

---

### B2 — PDB renders invalid `spec:` when neither `minAvailable` nor `maxUnavailable` set

**Status**: Fixed in 1.5.6
**File**: `templates/pdb.yaml` lines 18–30

**Problem**: When neither `minAvailable` nor `maxUnavailable` is provided, the template
still renders `spec:` containing only a `selector:` — no disruption budget key.
Kubernetes rejects the apply with a validation error.

**Fix**: Guard the entire PDB render with a check that at least one of `minAvailable`
or `maxUnavailable` is present, or fail with a descriptive `required` message.

---

### B3 — `progressDeadlineSeconds` always emitted on Deployment with hardcoded 600 fallback

**Status**: Fixed in 1.5.6
**File**: `templates/deployment.yaml` line 24

**Problem**: `dig "progressDeadlineSeconds" (dig "progressDeadlineSeconds" 600 $general) $d`
always resolves to `600` when the user hasn't set it. This emits
`progressDeadlineSeconds: 600` on every Deployment even when the user didn't set it,
creating unnecessary `helm diff` noise and preventing Kubernetes from using its own default.

**Fix**: Use a nil sentinel. Only emit the field when explicitly set by the user at any
tier. Also add `progressDeadlineSeconds` to the `defaults` cascade (instance → general →
defaults → omit).

---

### B4 — `podAffinity: {}` / `podAntiAffinity: {}` rendered when preset is `""`

**Status**: Fixed in 1.5.6
**File**: `templates/helpers/_affinities.tpl` lines 43–46, 55–58

**Problem**: `helpers.affinities.nodes` and `helpers.affinities.pods` return `{}`
(the literal string `{}`) when the type is an empty string. In `_pod.tpl`,
`podAffinity:` and `podAntiAffinity:` are then rendered with that value, producing:

```yaml
affinity:
  podAffinity: {}
  podAntiAffinity: {}
```

Kubernetes treats `podAffinity: {}` differently from omitting the key (it signals
that affinity is configured with no terms, which triggers extra scheduling logic).
With the default presets `"soft"` this is mostly invisible, but when a user sets
`podAffinityPreset: ""` explicitly to disable pod affinity, the empty object is
rendered instead of omitting the key entirely.

**Fix**: Return an empty string `""` instead of `{}` when type is `""`. The
`{{- if ... }}` guards in `_pod.tpl` will suppress rendering via `trim`.

---

### B5 — PVC `disabled: true` does not prevent volume injection

**Status**: Investigated in 1.5.6, confirmed already fixed  
**File**: `templates/helpers/_volumes.tpl` lines 69, 81, 104

**Finding**: The `disabled` guard is present and correct at all three injection
points (`autoPvcVolumes`, `autoPvcMounts`, `renderVolume`). This issue does not
reproduce. No fix needed.

---

### B6 — PVC `workloads:` scoping confirmed implemented

**Status**: Investigated in 1.5.6, confirmed already fixed  
**File**: `templates/helpers/_volumes.tpl` lines 69, 81, 104

**Finding**: The `workloads` filter (`has $workloadName $p.workloads`) is present and
correct in all three injection points. This issue does not reproduce. No fix needed.

---

## 🟡 Footguns

### F1 — `unhealthyPodEvictionPolicy` in PDB has no K8s version guard

**Status**: Fixed in 1.5.6
**File**: `templates/pdb.yaml` lines 24–26

**Problem**: `unhealthyPodEvictionPolicy` requires Kubernetes 1.27+. Clusters on
1.26 or earlier will fail the `kubectl apply` with an unknown field error.

**Fix**: Gate with `semverCompare ">=1.27-0" .Capabilities.KubeVersion.GitVersion`.

---

### F2 — `suspend: false` always emitted on every CronJob

**Status**: Fixed in 1.5.6
**File**: `templates/cronjob.yaml` line 14

**Problem**: `suspend: {{ default false .suspend }}` emits `suspend: false` on every
CronJob even when the user never set it. This is noisy in `helm diff` output and
inconsistent with how other fields are handled (nil guard pattern).

**Fix**: Gate with nil check — only emit when explicitly set.

---

### F3 — `defaults.securityContext` (deprecated alias) ignored at defaults tier

**Status**: Fixed in 1.5.6
**File**: `templates/helpers/_pod.tpl` lines 12–15, 147–151

**Problem**: At instance and general levels, both `securityContext` and
`podSecurityContext` are checked (the deprecated alias is supported). But at
the defaults tier (line 147), only `$.Values.defaults.podSecurityContext` is checked.
If a user sets `defaults.securityContext` (matching the pattern at instance level),
it is silently ignored.

**Fix**: Also check `$.Values.defaults.securityContext` as a fallback at the defaults
tier, consistent with instance and general tiers.

---

### F4 — Auto-generated Service ports hardcoded to TCP

**Status**: Fixed in 1.5.6
**File**: `templates/autoservices.yaml` (auto-generated Service from workload `ports:` map)  
**File**: `templates/helpers/_workloads.tpl` (container port rendering)

**Problem**: The `ports:` map shorthand (`{http: 8080}`) always renders `protocol: TCP`.
UDP services are impossible to create via the shorthand.

**Fix**: Extended the ports map to accept either `{name: port}` (simple form, defaults
to TCP) or `{name: {port: N, protocol: P}}` (extended form with explicit protocol).
Both auto-generated Service ports and container ports honour the new format.
Schema updated to accept `oneOf` integer or `{port, protocol}` object.

---

## 🔵 Schema Gaps

### S1 — `revisionHistoryLimit` missing from `defaults` schema

**Status**: Fixed in 1.5.6
**File**: `values.schema.json` `defaults.properties`

**Problem**: `defaults.revisionHistoryLimit` is set in `values.yaml` and used in
templates, but the `defaults.properties` block in the schema does not declare it.
Any user who sets `defaults.revisionHistoryLimit` gets a schema validation error.

**Fix**: Add `"revisionHistoryLimit": { "type": "integer", "minimum": 0 }` to
`defaults.properties`.

---

### S2 — `dnsConfig` missing from `defaults` schema

**Status**: Fixed in 1.5.6
**File**: `values.schema.json` `defaults.properties`

**Problem**: `defaults.dnsConfig` is used in templates (`_pod.tpl` line 90) but
not declared in `defaults.properties` in the schema.

**Fix**: Add `"dnsConfig": { "type": "object", "additionalProperties": true }` to
`defaults.properties`.

---

### S3 — `workloadGeneral` missing several fields present in `workload`

**Status**: Fixed in 1.5.6
**File**: `values.schema.json` `$defs.workloadGeneral`

**Problem**: The following fields exist in `workload` but not in `workloadGeneral`,
breaking the cascade symmetry — users cannot set them at the kind-level `*General`
tier:

| Missing field | Type |
|---|---|
| `restartPolicy` | string |
| `commandDurationAlert` | integer |
| `podManagementPolicy` | string |
| `lifecycle` | object |
| `startupProbe` | object |
| `livenessProbe` | object |
| `readinessProbe` | object |
| `healthCheck` | object ($ref) |
| `concurrencyPolicy` | string |

**Fix**: Add all missing fields to `workloadGeneral.properties`.

---

### S4 — `concurrencyPolicy` missing from workload/cronJob schema

**Status**: Fixed in 1.5.6 (see B1 above)

---

### S5 — `immutable` field missing from ConfigMap and Secret

**Status**: Fixed in 1.5.6
**File**: `templates/configmap.yaml`  
**File**: `templates/secret.yaml`  
**File**: `values.schema.json` `$defs.configMap`, `$defs.secret`

**Problem**: Kubernetes supports `immutable: true` on ConfigMaps and Secrets to
prevent mutations and improve kubelet performance at scale. The chart does not
render the `immutable:` field.

**Fix**: Add `immutable` passthrough to both templates and their schema definitions.

---

## ⚪ Minor / Polish

### M1 — `overhead`, `readinessGates`, `schedulingGates`, `os` cascade missing defaults tier

**Status**: Fixed in 1.5.6
**File**: `templates/helpers/_pod.tpl` lines 209–228

**Problem**: These four fields (added in 1.5.5) have instance → general cascade but
no defaults tier. Rarely set globally, but breaks the 3-tier consistency guarantee.

**Fix**: Added the defaults tier check for each field, matching the pattern
of all other 3-tier fields.

---

### M2 — `issuer.yaml` line 3: `$_` variable assigned but result discarded

**Status**: Fixed in 1.5.6
**File**: `templates/issuer.yaml` line 3

**Problem**: `{{- $_ := include "helpers.tplvalues.render" ... }}` stores the result
in `$_` but it's never used — the same expression is evaluated again on line 4. The
`$_` assignment is wasted work but produces no incorrect output.

**Fix**: Inlined the `include` call directly into the `ternary` expression,
removing the unnecessary intermediate variable.

---

### M3 — `istiovirtualservice.yaml` emits `name: ""` for every http route

**Status**: Fixed in 1.5.6
**File**: `templates/istiovirtualservice.yaml` line 29

**Problem**: `- name: {{ $httpRoute.name | default "" | quote }}` emits `name: ""`
when no name is set. Istio accepts this but it creates diff noise.

**Fix**: Gate with `{{- with $httpRoute.name }}` so the `name:` key is omitted when
not set.

---

### M4 — `istiodestinationrule.yaml`: `trafficPolicy:` always emitted even when empty

**Status**: Fixed in 1.5.6
**File**: `templates/istiodestinationrule.yaml` lines 20–23

**Problem**: The `trafficPolicy:` key is always emitted at the top-level `spec:`.
When `.trafficPolicy` is nil, the rendered YAML is `trafficPolicy:` with nothing
under it — an empty scalar that Istio may reject or misinterpret.

**Fix**: Gate the `trafficPolicy:` key emission with
`{{- with $destinationrule.trafficPolicy }}` so it is only emitted when set.

---

### M5 — Port protocol hardcoded to TCP in `helpers.workload.singleContainerPorts`

**Status**: Fixed in 1.5.6 (see F4 above)
**File**: `templates/helpers/_workloads.tpl`

**Problem**: Container port rendering from map-form `ports:` always sets
`protocol: TCP`. Same root cause as F4 — fixed together.

---

## Resolved Issues (previous sessions)

See `CHANGELOG.md` for all issues fixed in versions 1.5.0–1.5.5.

| Version | Issues fixed |
|---|---|
| 1.5.1 | HPA integer types, imagePullSecrets dedup, allocateLoadBalancerNodePorts |
| 1.5.2 | dnsConfig cascade, automountServiceAccountToken, revisionHistoryLimit cascade, revisionHistoryLimit=0/minReadySeconds=0 drops, publishNotReadyAddresses=false, preStopSleep cascade |
| 1.5.3 | envsFromSecret/envsFromConfigmap rewrite |
| 1.5.4 | HPA empty metrics key, schema gaps (minReadySeconds, extraImagePullSecrets, preStopSleep), stringData in Secret, PDB duplicate-key bug |
| 1.5.5 | hostNetwork/hostPID/hostIPC/shareProcessNamespace added, hook deletePolicy default fixed, hooksGeneral cascade, runtimeClassName/automountServiceAccountToken/overhead/readinessGates/schedulingGates/os added to schema+pod |
