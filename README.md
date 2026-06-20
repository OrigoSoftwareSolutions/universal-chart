# Origo Universal Helm Chart

![Version: 1.9.7](https://img.shields.io/badge/Version-1.9.7-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

One Helm chart, one workload per release. Define your Kubernetes resources — Deployment (or StatefulSet, DaemonSet, Job, CronJob) plus supporting resources (Service, HPA, ServiceAccount, ExternalSecret, Istio configs, and more) — in a single values file.

> **1.9.6 is a breaking change from v1.x.** The multi-workload dict-iteration pattern, `*General` sections, `releasePrefix`, auto-generated `envs`/`secretEnvs`, and `hooks` have been removed. See the [migration guide](#migration-from-v1x) below.

---

## Supported Resources

| Core Workload | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PVC | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | StorageClass / PV | PrometheusRule (via job) |
| HPA / PDB | ServiceMonitor | ServiceAccount | ImageUpdater (Argo CD) |
| | | | Istio DestinationRule / PeerAuthentication / AuthorizationPolicy |

## Quick Start

```yaml
# values.yaml
deployment:
  image: nginx
  imageTag: "1.25"
  replicas: 2
  ports:
    http: 8080
  healthCheck:
    path: /healthz
    port: 8080
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

service:
  ports:
    - port: 80
      targetPort: 8080
```

```bash
helm install my-app oci://ghcr.io/origosoftwaresolutions/universal-chart \
  --values values.yaml \
  --namespace my-ns
```

---

## Architecture

### Singular Blocks

Every resource type is a **singular block** — not a dict of instances. The chart creates at most one of each kind per release:

```yaml
deployment:          # ← singular block (was `deployments:`)
  image: nginx
  replicas: 2

service:             # ← singular block (was `services:`)
  ports:
    - port: 80

hpa:                 # ← singular block (was `hpas:`)
  minReplicas: 2
  maxReplicas: 10
```

### Dict-Based Resources

Resources that are naturally multiple per release use the **dict pattern** (one key per instance):

```yaml
configMaps:           # ← dict (unchanged from v1)
  app-config:
    data:
      KEY: value
  other-config:
    data:
      FOO: bar

certificates:         # ← dict
  my-cert:
    spec:
      secretName: my-tls
      issuerRef:
        name: letsencrypt
        kind: ClusterIssuer
      dnsNames: [example.com]
```

### Resource Naming

Singular blocks use **literal names**:

```yaml
deployment:
  name: my-app       # → K8s resource named "my-app"
  image: nginx

service:
  # name omitted     # → defaults to .Release.Name (the Helm release name)
  ports:
    - port: 80
```

Dict-based resources use `{release-name}-{key}`:

```yaml
configMaps:
  app-config:        # → K8s resource named "my-app-app-config"
    data:
      KEY: value
```

---

## Workloads

Pick **one** workload type per release. All share the same base configuration fields.

### Deployment

```yaml
deployment:
  name: my-app       # optional — defaults to release name
  image: nginx
  imageTag: "1.25"
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### StatefulSet

```yaml
statefulset:
  name: my-sts
  image: postgres:16
  serviceName: my-sts-svc
  podManagementPolicy: OrderedReady
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 10Gi
```

### DaemonSet

```yaml
daemonset:
  name: my-ds
  image: fluentd
  imageTag: "v1.17"
```

### Job

```yaml
job:
  name: db-migration
  image: myapp-migration
  restartPolicy: Never
  backoffLimit: 3
  ttlSecondsAfterFinished: 60
  commandDurationAlert: 300   # Creates PrometheusRule
```

### CronJob

```yaml
cronJob:
  name: nightly-report
  image: report-generator
  schedule: "0 2 * * *"
  concurrencyPolicy: Replace
  successfulJobsHistoryLimit: 3
  commandDurationAlert: 600
```

### Environment Variables

```yaml
deployment:
  image: myapp
  env:
    - name: LOG_LEVEL
      value: info
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: myapp-secrets
          key: db-password
  envFrom:
    - secretRef:
        name: myapp-secrets
  envConfigmaps:
    - myapp-config          # injects entire ConfigMap via envFrom
  envSecrets:
    - myapp-secrets         # injects entire Secret via envFrom
```

### Health Check Shorthand

```yaml
deployment:
  image: myapp
  healthCheck:
    path: /healthz
    port: 8080
    initialDelaySeconds: 5
    periodSeconds: 10
    failureThreshold: 3
```

This generates startup, liveness, and readiness HTTP probes automatically.

---

## Service

```yaml
service:
  name: my-svc
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
```

The selector automatically targets the workload's `app.kubernetes.io/component` label. Override with `selector:` or add `extraSelectorLabels:`.

---

## ServiceAccount (with RBAC)

`serviceAccount` is a list — each item creates one ServiceAccount. Use one item for the common case, multiple items when a release needs separate cloud identities (e.g. a migration job with its own WorkloadIdentity):

```yaml
serviceAccount:
  - name: my-app
    role:
      name: my-role
      rules:
        - apiGroups: [""]
          resources: [pods]
          verbs: [get, list, watch]
    clusterRole:
      name: my-cr
      rules:
        - apiGroups: [""]
          resources: [nodes]
          verbs: [get, list]
  - name: my-app-migration
    annotations:
      azure.workload.identity/client-id: "migration-client-id"
      argocd.argoproj.io/sync-wave: "-3"
```

Each item supports: `name`, `labels`, `annotations`, `automountServiceAccountToken`, `imagePullSecrets`, `secrets`, `role`, `clusterRole`.

`role` generates: Role + RoleBinding. `clusterRole` generates: ClusterRole + ClusterRoleBinding.

### PreSync migration job pattern

A common pattern for apps that run DB migrations before deployment — two separate cloud identities, migration job runs as a PreSync hook:

```yaml
serviceAccount:
  - name: my-app
    labels:
      azure.workload.identity/use: "true"
    annotations:
      azure.workload.identity/client-id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      azure.workload.identity/tenant-id: "ffffffff-0000-1111-2222-333333333333"
  - name: my-app-migration
    labels:
      azure.workload.identity/use: "true"
    annotations:
      azure.workload.identity/client-id: "11111111-2222-3333-4444-555555555555"
      azure.workload.identity/tenant-id: "ffffffff-0000-1111-2222-333333333333"
      argocd.argoproj.io/sync-wave: "-3"

job:
  name: my-app-migration
  image: myregistry.azurecr.io/my-app
  imageTag: ""
  serviceAccountName: my-app-migration
  restartPolicy: Never
  ttlSecondsAfterFinished: 60
  activeDeadlineSeconds: 300
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"
  podAnnotations:
    sidecar.istio.io/inject: "false"
  podLabels:
    azure.workload.identity/use: "true"

deployment:
  name: my-app
  image: myregistry.azurecr.io/my-app
  imageTag: ""
  serviceAccountName: my-app

service:
  name: my-app
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

---

## Autoscaling & Availability

### HPA

```yaml
hpa:
  scaleTargetRef:
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  targetCPU: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
```

### PDB

```yaml
pdb:
  minAvailable: 1
  unhealthyPodEvictionPolicy: IfHealthyBudget
```

---

## Storage

### PVC

```yaml
pvc:
  name: app-data
  accessModes: [ReadWriteOnce]
  size: 8Gi
  storageClassName: managed-premium
```

### PersistentVolume

```yaml
persistentVolumes:
  azure-share:
    spec:
      capacity:
        storage: 50Gi
      accessModes: [ReadWriteMany]
      azureFile:
        secretName: azure-storage-secret
        shareName: my-share
```

### ConfigMaps (dict)

```yaml
configMaps:
  app-config:
    data:
      APP_ENV: production
      LOG_FORMAT: json
  nginx-config:
    data:
      nginx.conf: |
        server { ... }
```

### Secrets (dict)

```yaml
secrets:
  api-keys:
    type: Opaque
    data:
      api.key: {{ .Values.myApiKey | b64enc }}
    stringData:
      other.key: plain-text-value
```

---

## External Secrets Operator

```yaml
externalSecret:
  name: my-secrets
  spec:
    refreshInterval: 1h
    secretStoreRef:
      name: cluster-secret-store
      kind: ClusterSecretStore
    target:
      name: myapp-secrets
    data:
      - secretKey: db-password
        remoteRef:
          key: azure-kv-db-password
      - secretKey: api-key
        remoteRef:
          key: azure-kv-api-key
```

---

## Istio

```yaml
istioGateways:
  public:
    selector:
      istio: ingressgateway
    servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts: ["myapp.example.com"]

istioVirtualServices:
  myapp:
    gateways: [public]
    hosts: ["myapp.example.com"]
    http:
      - match:
          - uri:
              prefix: /
        route:
          - destination:
              host: my-svc.{{ .Release.Namespace }}.svc.cluster.local
              port:
                number: 80
```

---

## cert-manager

```yaml
certificates:
  my-tls:
    spec:
      secretName: my-tls
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames: [myapp.example.com]

clusterIssuers:
  letsencrypt-prod:
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: devops@example.com
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers: []
```

---

## Argo CD Image Updater

```yaml
imageUpdater:
  name: my-app
  applicationName: "my-argocd-app"
  metadataNamespace: argocd
  images:
    - alias: app
      imageName: ghcr.io/myorg/myapp
      updateStrategy: newest-build
      allowTags: 'regexp:^\d+\.\d+\.\d+$'
      manifestTargets:
        helm:
          name: deployment.image
          tag: deployment.imageTag
  writeBackConfig:
    method: argocd
```

---

## Default Settings

The `defaults` section provides shared configuration for all resources:

```yaml
defaults:
  labels:
    team: platform
  annotations:
    prometheus.io/scrape: "true"
  podSecurityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: [ALL]
  revisionHistoryLimit: 3
  usePredefinedAffinity: true
```

Defaults cascade per-field: a value set on the workload block overrides the defaults value for that field only.

---

## Global Settings

```yaml
defaultImagePullPolicy: IfNotPresent
imagePullSecrets:
  - acr-pull-secret
nameOverride: ""        # Override chart name in resource labels

podAffinityPreset: soft
podAntiAffinityPreset: soft
nodeAffinityPreset:
  type: ""
  key: ""
  values: []

diagnosticMode:
  enabled: false
  command: ["sleep"]
  args: ["infinity"]
```

---

## Escape Hatch

```yaml
extraDeploy:
  network-policy: |-
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: {{ .Release.Name }}-deny-all
      namespace: {{ .Release.Namespace | quote }}
    spec:
      podSelector: {}
      policyTypes: [Ingress, Egress]
```

---

## Migration from v1.x

The following v1.x features have been removed:

| v1.x Feature | Replacement |
|---|---|
| `deployments:` dict | `deployment:` singular block |
| `services:` dict | `service:` singular block |
| `hpas:` dict | `hpa:` singular block |
| `*General` sections | Use `defaults:` for shared config |
| `releasePrefix` | Use `name:` field on each block |
| `envs:` / `secretEnvs:` auto-generation | Define `env:` inline on the workload |
| `hooks:` section | Define `job:` with ArgoCD hook annotations on `job.annotations:` |
| `disabled: true` on resources | Omit the resource block entirely |

### Migration Steps

1. **Flatten multi-workload releases:** If you had multiple deployments in one values file, split them into separate releases:
   ```yaml
   # v1.x — one release, two deployments
   deployments:
     api:
       image: myapp-api
     worker:
       image: myapp-worker
   ```
   ```yaml
   # new — two releases
   # Release "myapp-api": deployment.image: myapp-api
   # Release "myapp-worker": deployment.image: myapp-worker
   ```

2. **Rename dict keys to singular blocks:**
   - `deployments:` → `deployment:`
   - `services:` → `service:`
   - `hpas:` → `hpa:`
   - `pdbs:` → `pdb:`
   - `pvcs:` → `pvc:`
   - `externalSecrets:` → `externalSecret:`
   - `imageUpdaters:` → `imageUpdater:`
   - `serviceAccounts:` → `serviceAccount:` (now a list — each item is `{name: ..., annotations: ...}`)

3. **Move *General values to defaults or inline:**
   ```yaml
   # v1.x
   deploymentsGeneral:
     podSecurityContext:
       fsGroup: 1000
   # new — move to defaults or set on the workload directly
   defaults:
     podSecurityContext:
       fsGroup: 1000
   ```

4. **Replace envs/secretEnvs with inline env:**
   ```yaml
   # v1.x
   envs:
     LOG_LEVEL: info
   secretEnvs:
     DB_PASSWORD: s3cret
   # new
   deployment:
     env:
       - name: LOG_LEVEL
         value: info
       - name: DB_PASSWORD
         valueFrom:
           secretKeyRef:
             name: my-secrets
             key: db-password
   ```

5. **Replace releasePrefix with explicit names:**
   ```yaml
   # v1.x: releasePrefix: "corp" → resources named "corp-web"
   releasePrefix: corp
   deployments:
     web: ...
   # new: deployment.name: "corp-web"
   deployment:
     name: corp-web
   ```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| certificates | object | `{}` | cert-manager Certificate resources (namespace-scoped). Each key becomes the resource name. |
| clusterExternalSecrets | object | `{}` | External Secrets Operator ClusterExternalSecret resources (cluster-scoped). Each key becomes the resource name. |
| clusterIssuers | object | `{}` | cert-manager ClusterIssuer resources (cluster-scoped, no namespace). Each key becomes the resource name. |
| clusterSecretStores | object | `{}` | External Secrets Operator ClusterSecretStore resources (cluster-scoped). Each key becomes the resource name. |
| configMaps | object | `{}` | Kubernetes ConfigMap resources. Each key becomes the resource name. |
| cronJob | object | `{}` | Kubernetes CronJob.  Only one per release. |
| daemonset | object | `{}` | Kubernetes DaemonSet.  Only one per release. |
| defaultImagePullPolicy | string | `"IfNotPresent"` | Fallback image pull policy. One of: `Always`, `IfNotPresent`, `Never`. |
| defaults | object | `{"annotations":{},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"extraImagePullSecrets":[],"extraSelectorLabels":{},"extraVolumeMounts":[],"extraVolumes":[],"labels":{},"podAnnotations":{},"podLabels":{},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"revisionHistoryLimit":3,"usePredefinedAffinity":true}` | Default settings applied to all templates.  Labels, annotations, pod metadata, security contexts, resources, etc.  These are accessed directly (no merge cascade) — the workload block or resource block simply references defaults as needed. |
| defaults.annotations | object | `{}` | Annotations added to every resource's `metadata.annotations`. |
| defaults.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Default container-level securityContext. |
| defaults.extraImagePullSecrets | list | `[]` | Additional image pull secrets appended to every pod spec. |
| defaults.extraSelectorLabels | object | `{}` | Extra selector labels merged into workload `matchLabels`. |
| defaults.extraVolumeMounts | list | `[]` | Additional volume mounts appended to every container. |
| defaults.extraVolumes | list | `[]` | Additional volumes appended to every workload's pod spec. |
| defaults.labels | object | `{}` | Labels added to every resource's `metadata.labels`. |
| defaults.podAnnotations | object | `{}` | Annotations added to pod templates. |
| defaults.podLabels | object | `{}` | Labels added to pod templates. |
| defaults.podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Default pod-level securityContext. |
| defaults.revisionHistoryLimit | int | `3` | Default revisionHistoryLimit for Deployments and StatefulSets. |
| defaults.usePredefinedAffinity | bool | `true` | Use the chart's built-in pod affinity/anti-affinity rules. |
| deployment | object | `{}` | Kubernetes Deployment.  Only one per release. Single-container shorthand: set `image:` at workload level instead of `containers:`. `ports:` (map form) auto-creates containerPorts. Use the full `containers:` list for multi-container workloads. |
| diagnosticMode | object | `{"args":["infinity"],"command":["sleep"],"enabled":false}` | Diagnostic mode — overrides command/args on main containers only (init containers are not affected). |
| diagnosticMode.args | list | `["infinity"]` | Args override applied to every container. |
| diagnosticMode.command | list | `["sleep"]` | Command override applied to every container. |
| diagnosticMode.enabled | bool | `false` | Enable diagnostic mode globally. |
| externalSecret | object | `{}` | External Secrets Operator ExternalSecret.  Only one per release. |
| extraDeploy | object | `{}` | Raw Kubernetes manifests to deploy alongside chart resources. Supports template expressions. |
| hpa | object | `{}` | Kubernetes HorizontalPodAutoscaler (autoscaling/v2).  Only one per release. |
| httpRoutes | object | `{}` | Gateway API HTTPRoute resources. Each key becomes the resource name. |
| imagePullSecrets | list | `[]` | Image pull secret names referenced in every pod spec. Secrets must be pre-created in the namespace. |
| imageUpdater | object | `{}` | Argo CD Image Updater.  Only one per release. |
| issuers | object | `{}` | cert-manager Issuer resources (namespace-scoped). Each key becomes the resource name. |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key becomes the resource name. |
| istioDestinationRules | object | `{}` | Istio DestinationRule resources. Each key becomes the resource name. |
| istioGateways | object | `{}` | Istio Gateway resources. Each key becomes the resource name. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key becomes the resource name. |
| istioVirtualServices | object | `{}` | Istio VirtualService resources. Each key becomes the resource name. |
| job | object | `{}` | Kubernetes Job (non-hook).  Only one per release. |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration. |
| nodeAffinityPreset.key | string | `""` | Node label key to match (e.g. `kubernetes.io/e2e-az-name`). |
| nodeAffinityPreset.type | string | `""` | Affinity type. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset.values | list | `[]` | Node label values to match. |
| pdb | object | `{}` | Kubernetes PodDisruptionBudget.  Only one per release. |
| persistentVolumes | object | `{}` | Kubernetes PersistentVolume resources (cluster-scoped, no namespace). Each key becomes the resource name. |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| pvc | object | `{}` | Kubernetes PersistentVolumeClaim.  Only one per release. |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key becomes the resource name. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key becomes the resource name. |
| service | object | `{}` | Kubernetes Service.  Only one per release. |
| serviceAccount | list | `[]` | Kubernetes ServiceAccount(s). List — each item creates one ServiceAccount. Supports Role/ClusterRole per item. |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key becomes the resource name. |
| statefulset | object | `{}` | Kubernetes StatefulSet.  Only one per release. |
| storageClasses | object | `{}` | Kubernetes StorageClass resources (cluster-scoped, no namespace). Each key becomes the resource name. |
