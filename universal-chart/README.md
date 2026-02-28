# universal-chart

![Version: 1.1.5](https://img.shields.io/badge/Version-1.1.5-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

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
| defaultImageTag | string | `"latest"` | Fallback container image tag. |
| defaults | object | `{"annotations":{},"extraImagePullSecrets":[],"extraSelectorLabels":{},"extraVolumeMounts":[],"extraVolumes":[],"hookAnnotations":{},"labels":{},"podAnnotations":{},"podLabels":{},"usePredefinedAffinity":true}` | Default settings applied to all workload templates (labels, annotations, pod metadata, volumes, etc.) |
| defaults.annotations | object | `{}` | Annotations added to every resource's `metadata.annotations`. |
| defaults.extraImagePullSecrets | list | `[]` | Additional image pull secrets appended to every pod spec. |
| defaults.extraSelectorLabels | object | `{}` | Extra selector labels merged into workload `matchLabels`. |
| defaults.extraVolumeMounts | list | `[]` | Additional volume mounts appended to every container. |
| defaults.extraVolumes | list | `[]` | Additional volumes appended to every workload's pod spec. |
| defaults.hookAnnotations | object | `{}` | Default annotations for Helm hook resources. |
| defaults.labels | object | `{}` | Labels added to every resource's `metadata.labels`. |
| defaults.podAnnotations | object | `{}` | Annotations added to pod templates. |
| defaults.podLabels | object | `{}` | Labels added to pod templates. |
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

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
