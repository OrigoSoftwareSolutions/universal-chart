# universal-chart

![Version: 1.1.4](https://img.shields.io/badge/Version-1.1.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Origo universal Helm chart for all standard Kubernetes and CRD resources

**Homepage:** <https://github.com/OrigoSoftwareSolutions/universal-chart>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Origo SoftwareSolutions DevOps |  |  |

## Source Code

* <https://github.com/OrigoSoftwareSolutions/universal-chart>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clusterExternalSecrets | object | `{}` | External Secrets Operator ClusterExternalSecret resources (cluster-scoped). Each key becomes the resource name. |
| clusterIssuers | object | `{}` | cert-manager ClusterIssuer resources (cluster-scoped, no namespace). Each key becomes the resource name. |
| clusterSecretStores | object | `{}` | External Secrets Operator ClusterSecretStore resources (cluster-scoped). Each key becomes the resource name. |
| configMaps | object | `{}` | Kubernetes ConfigMap resources. Each key becomes the resource name. |
| cronJobs | object | `{}` | Kubernetes CronJob resources. Each key becomes the resource name. |
| cronJobsGeneral | object | `{"usePredefinedAffinity":false}` | Shared defaults for all CronJobs |
| daemonSets | object | `{}` | Kubernetes DaemonSet resources. Each key becomes the resource name. DaemonSets run one pod per node (no `replicas`). Uses `updateStrategy` instead of `strategy`. Supports all single-container shorthand fields: `image:`, `ports:`, `healthCheck:`, etc. |
| daemonSetsGeneral | object | `{}` | Shared defaults for all DaemonSets |
| defaultImage | string | `"nginx"` |  |
| defaultImagePullPolicy | string | `"IfNotPresent"` |  |
| defaultImageTag | string | `"latest"` |  |
| defaults | object | `{"annotations":{},"extraImagePullSecrets":[],"extraSelectorLabels":{},"extraVolumes":[],"hookAnnotations":{},"labels":{},"podAnnotations":{},"podLabels":{},"usePredefinedAffinity":true}` | Default settings applied to all workload templates (labels, annotations, pod affinity overrides, etc.) |
| deployments | object | `{}` | Kubernetes Deployment resources. Each key becomes the resource name. Single-container shorthand: set `image:` at workload level instead of a `containers:` list. `ports:` (map form {name: port}) auto-creates containerPorts AND a matching ClusterIP Service. `resources:` raw requests/limits map (presets removed — define your own). `healthCheck:` sets identical liveness, readiness, and startup probes. Override service behaviour with `service: false` (suppress) or `service: {type: NodePort}`. The full `containers:` list still works unchanged for multi-container workloads. |
| deploymentsGeneral | object | `{}` | Shared defaults for all Deployments (merged with per-instance values) |
| diagnosticMode.args[0] | string | `"infinity"` |  |
| diagnosticMode.command[0] | string | `"sleep"` |  |
| diagnosticMode.enabled | bool | `false` |  |
| envs | object | `{}` | Non-secret environment variables injected via ConfigMap envFrom |
| envsString | string | `""` | Non-secret environment variables as a raw YAML string (for multiline or special chars) |
| externalSecrets | object | `{}` | External Secrets Operator ExternalSecret resources. Each key becomes the resource name. |
| extraDeploy | object | `{}` | Raw Kubernetes manifests to deploy alongside chart resources. Supports template expressions. |
| hooks | object | `{}` | Helm lifecycle hook Jobs (pre/post-install/upgrade). Each key becomes the hook name. |
| hooksGeneral | object | `{}` | Shared defaults for all hook Jobs |
| hpas | object | `{}` | Kubernetes HorizontalPodAutoscaler resources (autoscaling/v2). Each key becomes the resource name. |
| httpRoutes | object | `{}` | Gateway API HTTPRoute resources. Each key becomes the resource name. |
| imagePullSecrets | object | `{}` |  |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key becomes the resource name. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key becomes the resource name. |
| istiodestinationrules | object | `{}` | Istio DestinationRule resources. Each key becomes the resource name. |
| istiogateways | object | `{}` | Istio Gateway resources. Each key becomes the resource name. |
| istiovirtualservices | object | `{}` | Istio VirtualService resources. Each key becomes the resource name. |
| jobs | object | `{}` | Kubernetes Job resources (non-hook). Each key becomes the resource name. |
| jobsGeneral.usePredefinedAffinity | bool | `false` |  |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, `nil` |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, `nil` |
| pvcs | object | `{}` | Kubernetes PersistentVolumeClaim resources. Each key becomes the resource name. All PVSs will be added to `volumes` block in each workload excluding hooks |
| releasePrefix | string | `""` | Prefix prepended to all resource names. Leave empty to disable. |
| secretEnvs | object | `{}` | Secret environment variables injected via Secret envFrom |
| secretEnvsString | string | `""` | Secret environment variables as a raw YAML string |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key becomes the resource name. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key becomes the resource name. |
| serviceAccount | object | `{}` | Kubernetes ServiceAccount resources. Each key becomes the resource name. |
| serviceAccountGeneral | object | `{}` |  |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key becomes the resource name. |
| services | object | `{}` | Kubernetes Service resources. Each key becomes the resource name. |
| statefulSets | object | `{}` | Kubernetes StatefulSet resources. Each key becomes the resource name. |
| statefulSetsGeneral | object | `{}` | Shared defaults for all StatefulSets |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
