# Origo Universal Helm Chart

![Version: 1.1.8](https://img.shields.io/badge/Version-1.1.8-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A single, opinionated Helm chart that can deploy **any** standard Kubernetes workload and popular CRD resources. Instead of maintaining dozens of per-service charts, define all your resources declaratively under one release.

## Supported Resources

| Core Workloads | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret / ClusterExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PersistentVolumeClaim | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | ServiceAccount | Istio PeerAuthentication |
| Helm Hooks | Istio DestinationRule | | Istio AuthorizationPolicy |
| HPA / PDB | ServiceMonitor | | |

## Quick Start

### Install from OCI registry

```bash
helm install my-release oci://ghcr.io/origosoftwaresolutions/universal-chart \
  --version 1.1.8 \
  -f my-values.yaml
```

### Minimal values example

```yaml
deployments:
  api:
    image: myapp
    imageTag: "1.0.0"
    ports:
      http: 8080
    healthCheck:
      path: /healthz
    resources:
      requests:
        cpu: 100m
        memory: 128Mi

envs:
  LOG_LEVEL: info
```

This creates a Deployment, a matching ClusterIP Service, liveness/readiness probes, a ConfigMap with environment variables — all from one values file.

## Features Worth Knowing About

### Auto-generated Services

When a workload uses the single-container shorthand with a `ports:` map, a matching ClusterIP Service is created automatically — no separate `services:` block needed. Suppress it with `service: false` or customize with `service: { type: NodePort }`.

### Single-Container Shorthand

Instead of a full `containers:` list, set `image:`, `ports:`, `resources:`, `healthCheck:` directly on the workload. The chart synthesizes the container spec for you.

### Health Check Shorthand

A single `healthCheck: { path: /healthz }` generates startup, liveness, **and** readiness probes simultaneously (HTTP GET, port 8080, 10s period by default).

### Resource Presets

Set `resources: small` (or `nano`, `medium`, `large`, `xlarge`) instead of writing full requests/limits blocks. The chart expands presets into concrete CPU/memory values.

### Typed Volumes

Volumes use a simplified format — `{ type: configMap, name: my-cm }` — instead of raw Kubernetes volume specs. Supports `configMap`, `secret`, `pvc`, `emptyDir`, and more.

### PVCs Auto-Mounted

PVCs defined in `pvcs:` are automatically added to workload volume lists — no manual `volumes:` wiring required.

### Template Expressions in Values

Go template expressions work anywhere in values. Write `"{{ .Release.Name }}-suffix"` and it renders at deploy time.

### Environment Variable Shorthand

Top-level `envs:` and `secretEnvs:` maps auto-create ConfigMaps/Secrets and inject them via `envFrom`. Use `envsFromConfigmap` / `envsFromSecret` to cherry-pick individual keys from existing resources.

### Base64 Auto-Decode

ConfigMap values prefixed with `b64:` are automatically decoded from base64 before rendering.

### 3-Tier Defaults Cascade

`defaults` (global) → `deploymentsGeneral` (kind-level) → per-instance values. Set shared config once, override where needed.

### Diagnostic Mode

Set `diagnosticMode.enabled: true` to override all containers with `sleep infinity` — useful for debugging pods that crash-loop.

### Disable Without Deleting

Any resource instance accepts `disabled: true` to suppress rendering without removing its configuration.

### Escape Hatch

`extraDeploy:` accepts raw Kubernetes manifests (with template support) for anything the chart doesn't natively cover.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| certificates | object | `{}` | cert-manager Certificate resources (namespace-scoped). Each key becomes the resource name. |
| clusterExternalSecrets | object | `{}` | External Secrets Operator ClusterExternalSecret resources (cluster-scoped). Each key becomes the resource name. |
| clusterIssuers | object | `{}` | cert-manager ClusterIssuer resources (cluster-scoped, no namespace). Each key becomes the resource name. |
| clusterSecretStores | object | `{}` | External Secrets Operator ClusterSecretStore resources (cluster-scoped). Each key becomes the resource name. |
| configMaps | object | `{}` | Kubernetes ConfigMap resources. Each key becomes the resource name. |
| cronJobs | object | `{}` | Kubernetes CronJob resources. Each key becomes the resource name. |
| cronJobsGeneral | object | `{"usePredefinedAffinity":false}` | Shared defaults for all CronJobs. |
| daemonSets | object | `{}` | Kubernetes DaemonSet resources. Each key becomes the resource name. DaemonSets run one pod per node (no `replicas`). Uses `updateStrategy` instead of `strategy`. |
| daemonSetsGeneral | object | `{}` | Shared defaults for all DaemonSets. |
| defaultImage | string | `"nginx"` | Fallback container image used when a workload omits `image`. |
| defaultImagePullPolicy | string | `"IfNotPresent"` | Fallback image pull policy. One of: `Always`, `IfNotPresent`, `Never`. |
| defaultImageTag | string | `"v0.0.1"` | Fallback container image tag. |
| defaults | object | `{"annotations":{},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"extraImagePullSecrets":[],"extraSelectorLabels":{},"extraVolumeMounts":[],"extraVolumes":[],"hookAnnotations":{},"labels":{},"podAnnotations":{},"podLabels":{},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"resources":{"requests":{"cpu":"100m","memory":"128Mi"}},"usePredefinedAffinity":true}` | Default settings applied to all workload templates (labels, annotations, pod metadata, volumes, etc.) |
| defaults.annotations | object | `{}` | Annotations added to every resource's `metadata.annotations`. |
| defaults.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Default container-level securityContext applied to every container. |
| defaults.extraImagePullSecrets | list | `[]` | Additional image pull secrets appended to every pod spec. |
| defaults.extraSelectorLabels | object | `{}` | Extra selector labels merged into workload `matchLabels`. |
| defaults.extraVolumeMounts | list | `[]` | Additional volume mounts appended to every container. |
| defaults.extraVolumes | list | `[]` | Additional volumes appended to every workload's pod spec. |
| defaults.hookAnnotations | object | `{}` | Default annotations for Helm hook resources. |
| defaults.labels | object | `{}` | Labels added to every resource's `metadata.labels`. |
| defaults.podAnnotations | object | `{}` | Annotations added to pod templates. |
| defaults.podLabels | object | `{}` | Labels added to pod templates. |
| defaults.podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Default pod-level securityContext applied to every pod spec. |
| defaults.resources | object | `{"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resource requests/limits applied to containers when not overridden. |
| defaults.usePredefinedAffinity | bool | `true` | Use the chart's built-in pod affinity/anti-affinity rules. |
| deployments | object | `{}` | Kubernetes Deployment resources. Each key becomes the resource name. Single-container shorthand: set `image:` at workload level instead of a `containers:` list. `ports:` (map form `{name: port}`) auto-creates containerPorts AND a matching ClusterIP Service. `resources:` raw requests/limits map. `healthCheck:` sets liveness, readiness, and startup probes. Override service behaviour with `service: false` (suppress) or `service: {type: NodePort}`. The full `containers:` list still works for multi-container workloads. |
| deploymentsGeneral | object | `{}` | Shared defaults for all Deployments (merged with per-instance values). |
| diagnosticMode | object | `{"args":["infinity"],"command":["sleep"],"enabled":false}` | Diagnostic mode — overrides command/args on ALL containers (useful for debugging). |
| diagnosticMode.args | list | `["infinity"]` | Args override applied to every container. |
| diagnosticMode.command | list | `["sleep"]` | Command override applied to every container. |
| diagnosticMode.enabled | bool | `false` | Enable diagnostic mode globally. |
| envs | object | `{}` | Non-secret environment variables injected via ConfigMap envFrom. |
| envsString | string | `""` | Non-secret environment variables as a raw YAML string (for multiline or special chars). |
| externalSecrets | object | `{}` | External Secrets Operator ExternalSecret resources. Each key becomes the resource name. |
| extraDeploy | object | `{}` | Raw Kubernetes manifests to deploy alongside chart resources. Supports template expressions. |
| hooks | object | `{}` | Helm lifecycle hook Jobs (pre/post-install/upgrade). Each key becomes the hook name. |
| hooksGeneral | object | `{}` | Shared defaults for all hook Jobs. |
| hpas | object | `{}` | Kubernetes HorizontalPodAutoscaler resources (autoscaling/v2). Each key becomes the resource name. |
| httpRoutes | object | `{}` | Gateway API HTTPRoute resources. Each key becomes the resource name. |
| issuers | object | `{}` | cert-manager Issuer resources (namespace-scoped). Each key becomes the resource name. |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key becomes the resource name. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key becomes the resource name. |
| istiodestinationrules | object | `{}` | Istio DestinationRule resources. Each key becomes the resource name. |
| istiogateways | object | `{}` | Istio Gateway resources. Each key becomes the resource name. |
| istiovirtualservices | object | `{}` | Istio VirtualService resources. Each key becomes the resource name. |
| jobs | object | `{}` | Kubernetes Job resources (non-hook). Each key becomes the resource name. |
| jobsGeneral | object | `{"usePredefinedAffinity":false}` | Shared defaults for all Jobs. |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration. |
| nodeAffinityPreset.key | string | `""` | Node label key to match (e.g. `kubernetes.io/e2e-az-name`). |
| nodeAffinityPreset.type | string | `""` | Affinity type. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset.values | list | `[]` | Node label values to match. |
| pdbs | object | `{}` | Kubernetes PodDisruptionBudget resources. Each key becomes the resource name. |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| pvcs | object | `{}` | Kubernetes PersistentVolumeClaim resources. Each key becomes the resource name. PVCs are automatically added to the `volumes` block in each workload (excluding hooks). |
| releasePrefix | string | `""` | Prefix prepended to all resource names. Leave empty to disable. |
| secretEnvs | object | `{}` | Secret environment variables injected via Secret envFrom. |
| secretEnvsString | string | `""` | Secret environment variables as a raw YAML string. |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key becomes the resource name. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key becomes the resource name. |
| serviceAccount | object | `{}` | Kubernetes ServiceAccount resources. Each key becomes the resource name. |
| serviceAccountGeneral | object | `{}` | Shared defaults for all ServiceAccounts. |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key becomes the resource name. |
| services | object | `{}` | Kubernetes Service resources. Each key becomes the resource name. |
| statefulSets | object | `{}` | Kubernetes StatefulSet resources. Each key becomes the resource name. |
| statefulSetsGeneral | object | `{}` | Shared defaults for all StatefulSets. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Origo SoftwareSolutions DevOps |  |  |

## Development

```bash
# Lint
helm lint universal-chart/ --strict

# Render templates
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml

# Run unit tests (requires helm-unittest plugin)
helm unittest universal-chart/ --strict --file 'tests/*.yaml'

# Regenerate docs (required before commit)
helm-docs --chart-search-root universal-chart/ -o ../README.md

# Format
helmfmt universal-chart/
```

## Source Code

* <https://github.com/OrigoSoftwareSolutions/universal-chart>

## License

Maintained by [Origo Software Solutions](https://github.com/OrigoSoftwareSolutions).
