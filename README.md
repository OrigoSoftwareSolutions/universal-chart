# Origo Universal Helm Chart

![Version: 1.9.994](https://img.shields.io/badge/Version-1.9.994-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

One Helm chart, designed for one workload per release. Define your Kubernetes resources — Deployment (or StatefulSet, DaemonSet, Job, CronJob) plus supporting resources (Service, HPA, ServiceAccount, ExternalSecret, Istio configs, and more) — in a single values file.

---

## Supported Resources

| Core Workload | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PVC | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | StorageClass / PV | PrometheusRule (via job / cronJob) |
| HPA / VPA / PDB | ServiceMonitor / NetworkPolicy | ServiceAccount | ImageUpdater (Argo CD) |
| | | | Istio DestinationRule / PeerAuthentication / AuthorizationPolicy / EnvoyFilter |

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

Core resource types use a **singular block** — one instance per release, not a dict of instances:

```yaml
deployment:
  image: nginx
  replicas: 2

service:
  ports:
    - port: 80

hpa:
  minReplicas: 2
  maxReplicas: 10
```

### Dict-Based Resources

Resources that are naturally multiple per release use the **dict pattern** (one key per instance):

```yaml
configMaps:           # ← dict
  app-config:
    data:
      KEY: value
  other-config:
    data:
      FOO: bar

certificates:         # ← dict
  my-cert:
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

Dict-based resources default to `{release-name}-{key}`, but accept an optional `name:` field for a literal name:

```yaml
configMaps:
  app-config:        # → K8s resource named "my-app-app-config" (default)
    data:
      KEY: value

secretStores:
  main:
    name: my-app-store   # → K8s resource named "my-app-store" (literal override)
    spec: ...
```

Use the literal `name:` whenever you need to cross-reference the resource from another block in the same values file — so both sides use the same string:

```yaml
secretStores:
  main:
    name: my-app-store      # defined here

externalSecrets:
  my-secret:
    spec:
      secretStoreRef:
        name: my-app-store    # referenced here — same string, no release-name prefix to track

istioGateways:
  public:
    name: my-app-gateway    # defined here

istioVirtualServices:
  main:
    gateways:
      - my-app-gateway      # referenced here — same string
```

Without `name:`, the rendered name is `{release-name}-{key}` and you must use the full expanded name in any cross-reference.

---

## Namespace behavior in this release

> ⚠️ **Upgrade note:** As of this release, chart-managed resources no longer set `metadata.namespace` from `.Release.Namespace`.
> The target namespace now comes from your Helm/ArgoCD deployment context (`helm install --namespace ...` or ArgoCD `destination.namespace`).
> Keep explicit namespaces only where the API object must live elsewhere (for example ArgoCD Image Updater CRs in the ArgoCD namespace).

---

## Best-practices deviations

This chart tracks Helm best practices where possible, but the following seven gaps remain intentionally for compatibility in the current major version.

1. **`serviceAccount` stays a list (not a map).**
   Why not now: changing list semantics to a map would break existing values files and `--set` paths.
   v2 plan: migrate to map entries keyed by the current ServiceAccount name while preserving optional literal `name:` overrides.

2. **`app.kubernetes.io/name` equals the release name (not a static app name).**
   Why not now: correcting this would rewrite workload selectors, and those selectors are immutable on existing workloads.
   v2 plan: switch to app-name semantics with a documented delete/recreate migration for selector-bearing resources.

3. **RBAC shape differs from guide (`rbac.create` + `serviceAccount.create`/`serviceAccount.name`).**
   Why not now: RBAC is currently nested per `serviceAccount` entry (`role` / `clusterRole`) and is widely consumed in that structure.
   v2 plan: redesign RBAC/serviceAccount values into the guide-style split while providing an upgrade mapping from per-item nested blocks.

4. **Fixed image tags are not enforced.**
   Why not now: `image:` values without a tag are rendered as-is (untagged) by `templates/helpers/_container.tpl`; enforcing tags now would fail existing consumers.
   v2 plan: add strict validation for non-floating tags (or an explicit opt-out) and document migration expectations.

5. **`issuers.yaml` renders both `Issuer` and `ClusterIssuer` via `kind:` in one file.**
   Why not now: splitting behavior now would be a values/API break for current `issuers` users.
   v2 plan: route cluster-scoped entries to `clusterIssuers:` only, leaving `issuers:` namespace-scoped.

6. **`kubeVersion` is intentionally unset in `Chart.yaml`.**
   Why not now: adding it in a patch would hard-gate chart installs on cluster versions and break some current install paths.
   v2 plan: set an explicit supported range once enforced upgrade policy is introduced for the major release.

7. **`imageUpdater` keeps explicit `metadata.namespace` (defaults to `argocd`).**
   Why not now: the ArgoCD Image Updater CR must live in the ArgoCD control-plane namespace, not the workload release namespace.
   v2 plan: keep this as an intentional exception and document it as a namespaced-control-plane requirement.

---

## Operator prerequisites

Some values enable CRD-backed resources that require operators/controllers to already exist in the cluster.
`templates/helpers/_capabilities.tpl` performs API-version negotiation for several CRD-backed kinds and falls back to a default version when a CRD is absent.
That mechanism does **not** suppress rendering; if the operator/CRD is missing, failure happens when manifests are applied to the cluster.
`vpa` is rendered unconditionally, and `serviceMonitors`/`imageUpdater` use static apiVersions.

| Operator / stack | Values key(s) that need it | Version selection behavior | If missing |
|---|---|---|---|
| Istio | `istioGateways`, `istioVirtualServices`, `istioDestinationRules`, `istioAuthorizationPolicies`, `istioPeerAuthentications`, `istioEnvoyFilters` | Negotiated by `_capabilities.tpl` with fallback default | Apply-time CRD/API error |
| cert-manager | `certificates`, `issuers`, `clusterIssuers` | Negotiated by `_capabilities.tpl` with fallback default | Apply-time CRD/API error |
| External Secrets Operator | `externalSecrets`, `secretStores`, `clusterSecretStores`, `clusterExternalSecrets` | Negotiated by `_capabilities.tpl` with fallback default | Apply-time CRD/API error |
| Prometheus Operator | `serviceMonitors` and PrometheusRule generated by `job.commandDurationAlert` / `cronJob.commandDurationAlert` | Static apiVersions in templates | Apply-time CRD/API error |
| Gateway API | `httpRoutes` | Negotiated by `_capabilities.tpl` with fallback default | Apply-time CRD/API error |
| Vertical Pod Autoscaler (VPA) | `vpa` | Static `autoscaling.k8s.io/v1` (unconditional render) | Apply-time CRD/API error |
| ArgoCD Image Updater | `imageUpdater` | Static apiVersion in template | Apply-time CRD/API error |

---

## Selector and label caveats

- **`extraSelectorLabels` warning:** values under `service.extraSelectorLabels` are added to the workload selector match labels. Selector labels are immutable; never place mutable values there (for example version, build timestamp, release date).
- **PrometheusRule label caveat:** the chart adds standard labels to generated PrometheusRule objects. This is safe for normal subset-matching `ruleSelector`s; however, a selector that uses negative operators (`NotIn`, `DoesNotExist`) against an added key can change matching.

---

## Workloads

Each workload type is a singular optional block; the intended pattern is one per release. All workload types share the same base configuration fields.

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
```

### Auto-restart on config changes

`envConfigmaps` and `envSecrets` do not inject environment variables. They tell the chart which chart-managed ConfigMaps and Secrets the workload depends on so it can generate checksum annotations — causing a rolling restart whenever that data changes.

Entries must use `{release-name}-{key}` — the name derived from the dict key, not any literal `name:` override on the ConfigMap or Secret entry. If `configMaps.myapp-config.name: custom-name` is set, list `{release-name}-myapp-config` here, not `custom-name`:

```yaml
deployment:
  image: myapp
  envConfigmaps:
    - {{ .Release.Name }}-myapp-config    # = {release-name}-myapp-config
  envSecrets:
    - {{ .Release.Name }}-myapp-secrets   # = {release-name}-myapp-secrets

configMaps:
  myapp-config:
    data:
      LOG_LEVEL: info
```

To inject a ConfigMap as env vars, use `envFrom:` directly.

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

### Lifecycle Hooks

Set `lifecycle:` directly on the workload (single-container shorthand) or on each entry in `containers:`. The value is rendered verbatim — no automatic injection occurs. Init containers receive the same treatment as regular containers — lifecycle is applied when present.

The most common use case is a preStop drain delay to let in-flight requests complete before the container is terminated:

```yaml
deployment:
  image: myapp
  lifecycle:
    preStop:
      exec:
        command: ["sh", "-c", "sleep 5"]
```

For multi-container workloads, set it per container:

```yaml
deployment:
  image: myapp
  containers:
    - name: app
      image: myapp
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep 5"]
    - name: sidecar
      image: envoy
```

---

### Init Containers

Use `initContainers:` on any workload to run setup steps before the main container starts. Each entry follows the same structure as `containers:` — `name:` is optional and defaults to `{workload-name}-init-{index}`. The `healthCheck` shorthand and port mapping are not available for init containers.

```yaml
deployment:
  image: myapp
  initContainers:
    # wait for the database to be ready before starting the app
    - name: wait-for-db
      image: busybox
      command: ["sh", "-c", "until nc -z db 5432; do sleep 2; done"]
      env:
        - name: DB_HOST
          value: db
    # run migrations as a second init step
    - name: migrate
      image: myapp
      command: ["./migrate", "--up"]
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
```

Init containers share the workload's `volumes:` and `containerSecurityContext:` (deep-merged with any per-container `securityContext:`, same as regular containers).

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

The default selector uses the service name (defaults to `.Release.Name`) as the `app.kubernetes.io/component` value. When the workload name also defaults to `.Release.Name`, they match automatically. If `service.name` and the workload `name` differ, set an explicit `selector:` to target the correct component. Use `extraSelectorLabels:` only to add extra labels on top of the default selector.

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

Each item supports: `name`, `labels`, `annotations`, `imagePullSecrets`, `secrets`, `role`, `clusterRole`.

`role` with `rules:` generates Role + RoleBinding; without `rules:` generates only a RoleBinding to an existing Role. `clusterRole` works the same: with `rules:` generates ClusterRole + ClusterRoleBinding; without `rules:` generates only a ClusterRoleBinding.

### PreSync migration job pattern

A common pattern for apps that run DB migrations before deployment — two separate cloud identities, migration job runs as a PreSync hook:

```yaml
serviceAccount:
  - name: my-app
    annotations:
      azure.workload.identity/client-id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      azure.workload.identity/tenant-id: "ffffffff-0000-1111-2222-333333333333"
  - name: my-app-migration
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
    azure.workload.identity/use: "true"   # label goes on the pod, not the ServiceAccount

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

When `hpa` is set, the chart omits `replicas` from the Deployment/StatefulSet spec entirely, giving HPA full ownership of the replica count. This prevents GitOps tools such as ArgoCD from showing a perpetual diff on `spec.replicas` caused by HPA scaling the live count away from the chart-rendered value.

### VPA

VPA adjusts CPU and memory **requests** on running pods without changing the replica count — a good fit for single-replica workloads where horizontal scaling is not needed. Cannot be combined with `hpa`; the chart fails at render time if both are set.

```yaml
deployment:
  image: myapp
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

vpa:
  updatePolicy:
    updateMode: Recreate
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: "2"
          memory: 2Gi
```

`targetRef` defaults to `apps/v1 / Deployment / <release-name>` and can be overridden:

```yaml
vpa:
  targetRef:
    kind: StatefulSet
    name: my-sts
  updatePolicy:
    updateMode: Recreate
```

#### Update modes

| Mode | Behaviour | Min AKS version |
|---|---|---|
| `Recreate` | Evicts pods and recreates them with updated requests. Default when `updateMode` is omitted. | 1.24 |
| `Initial` | Sets requests only at pod creation; never updates live pods. | 1.24 |
| `Off` | Computes recommendations but makes no changes — read via `kubectl describe vpa`. | 1.24 |
| `InPlaceOrRecreate` | Resizes containers in-place first; evicts only if in-place is not possible. | 1.34 (AKS) |

> `Auto` is accepted but deprecated since VPA 1.4.0 — it is an alias for `Recreate`. Use `Recreate` explicitly.

#### AKS cluster prerequisites

VPA on AKS is a managed addon — no manual CRD installation required. Enable it via the `workload_autoscaler_profile` block in `azurerm_kubernetes_cluster` (requires azurerm provider **`>= 3.47.0`**):

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  # ... your existing cluster config ...

  workload_autoscaler_profile {
    vertical_pod_autoscaler_enabled = true
  }
}
```

The addon installs `autoscaling.k8s.io/v1` CRDs and the three VPA components (`vpa-recommender`, `vpa-updater`, `vpa-admission-controller`) into `kube-system`. Metrics Server — included by default on AKS — is the only additional dependency.

**Limitations to be aware of:**

- **Minimum Kubernetes version:** 1.24. `InPlaceOrRecreate` mode requires AKS 1.34+.
- **Windows containers** are not supported by VPA.
- **JVM workloads** — VPA cannot see inside JVM heap, so memory recommendations will be inaccurate. Consider setting `Off` mode and treating recommendations as advisory only.
- **VPA object count** — memory overhead grows with the number of pods under VPA management; Microsoft recommends staying under 1,000 pods per cluster with VPA objects attached.
- **Pre-existing CRDs** — if another tool (e.g. Goldilocks) already installed VPA CRDs, delete them before applying the Terraform change or the addon will fail silently:
  ```bash
  kubectl delete crd verticalpodautoscalers.autoscaling.k8s.io \
                      verticalpodautoscalercheckpoints.autoscaling.k8s.io
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
  keepOnDelete: true    # adds helm.sh/resource-policy: keep — PVC survives helm uninstall
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

### Consuming a PVC in a workload

Define the PVC, then wire it into the workload via `volumes:` and `volumeMounts:`:

```yaml
pvc:
  name: app-data
  accessModes: [ReadWriteOnce]
  size: 10Gi

deployment:
  image: myapp
  volumes:
    - name: data
      type: pvc
      claimName: app-data       # matches pvc.name above
  volumeMounts:
    - name: data
      mountPath: /var/app/data
```

To bind to a static PV from the same values file, set `pvc.volumeName`:

```yaml
persistentVolumes:
  my-share:
    name: my-pv                 # literal PV name
    spec:
      capacity:
        storage: 50Gi
      accessModes: [ReadWriteMany]
      azureFile:
        secretName: azure-storage-secret
        shareName: my-share

pvc:
  name: my-claim
  accessModes: [ReadWriteMany]
  storageClassName: ""          # empty string = disable dynamic provisioning (static binding)
  volumeName: my-pv             # matches persistentVolumes entry name above
  size: 50Gi
  keepOnDelete: true            # adds helm.sh/resource-policy: keep

deployment:
  image: myapp
  volumes:
    - name: uploads
      type: pvc
      claimName: my-claim
  volumeMounts:
    - name: uploads
      mountPath: /var/www/uploads
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
      api.key: {{ .Values.myApiKey }}    # plain value — chart applies b64enc automatically
    stringData:
      other.key: plain-text-value
  docker-pull:
    keepOnDelete: true
    type: kubernetes.io/dockerconfigjson
    stringData:
      .dockerconfigjson: '{"auths":{}}'
```

### StorageClasses (dict)

StorageClass fields are specified **directly** on each dict entry — there is no `spec:` wrapper.

```yaml
storageClasses:
  fast:
    provisioner: disk.csi.azure.com
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Retain
    allowVolumeExpansion: true
    parameters:
      skuName: Premium_LRS
  standard:
    isDefault: true              # adds storageclass.kubernetes.io/is-default-class: "true"
    provisioner: kubernetes.io/no-provisioner
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Delete
```

Supported fields: `provisioner` (required), `reclaimPolicy`, `volumeBindingMode`, `allowVolumeExpansion`, `parameters`, `mountOptions`, `allowedTopologies`, `isDefault`, `name`, `labels`, `annotations`, `disabled`.

---

## External Secrets Operator

### ExternalSecrets

Use `externalSecrets` (dict) — one key per secret, works for one or many:

```yaml
externalSecrets:
  # data: explicit key-by-key mapping
  db-credentials:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: my-store
        kind: SecretStore
      target:
        name: db-credentials
      data:
        - secretKey: db-password
          remoteRef:
            key: prod/myapp/db-password
        - secretKey: db-username
          remoteRef:
            key: prod/myapp/db-username

  # dataFrom.find: bulk-fetch all keys whose path matches a regexp
  app-config:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: my-store
        kind: SecretStore
      target:
        name: app-config
      dataFrom:
        - find:
            name:
              regexp: "^prod/myapp/config/"
```

### ClusterExternalSecret

Use `clusterExternalSecrets` to push a secret into multiple namespaces at once:

```yaml
clusterExternalSecrets:
  # data: explicit key mapping, pushed to a specific namespace
  db-credentials:
    spec:
      namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: my-namespace
      refreshTime: 1h
      externalSecretSpec:
        refreshInterval: 1h
        secretStoreRef:
          name: cluster-store
          kind: ClusterSecretStore
        target:
          name: db-credentials
        data:
          - secretKey: db-password
            remoteRef:
              key: prod/shared/db-password

  # dataFrom.find: bulk-fetch by regexp, pushed to all production namespaces
  app-secrets:
    spec:
      namespaceSelector:
        matchLabels:
          environment: production
      refreshTime: 1h
      externalSecretSpec:
        refreshInterval: 1h
        secretStoreRef:
          name: cluster-store
          kind: ClusterSecretStore
        target:
          name: app-secrets
        dataFrom:
          - find:
              name:
                regexp: "^prod/shared/"
```

---

## Istio

Three resource types — `istioGateways`, `istioVirtualServices`, `istioDestinationRules` — use **direct fields** (no `spec:` wrapper). Three — `istioAuthorizationPolicies`, `istioPeerAuthentications`, `istioEnvoyFilters` — use **`spec:` passthrough**.

### Gateways and VirtualServices

```yaml
istioGateways:
  public:
    name: my-app-gateway
    selector:
      istio: ingressgateway
    servers:
      https:
        hosts:
          - myapp.example.com
        port:
          name: https
          number: 443
          protocol: HTTPS

istioVirtualServices:
  myapp:
    hosts:
      - myapp.example.com
    gateways:
      - my-app-gateway
    http:
      - name: default
        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
        route:
          - destination:
              host: my-svc.{{ .Release.Namespace }}.svc.cluster.local
              port:
                number: 80
```

### DestinationRules

```yaml
istioDestinationRules:
  my-svc:
    host: my-svc.default.svc.cluster.local
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
      loadBalancer:
        simple: ROUND_ROBIN
      outlierDetection:
        consecutive5xxErrors: 5
        interval: 30s
        baseEjectionTime: 30s
```

### AuthorizationPolicies and PeerAuthentications

These two use `spec:` passthrough — all CRD fields go under `spec:`.

```yaml
istioAuthorizationPolicies:
  deny-external:
    spec:
      action: DENY
      rules:
        - from:
            - source:
                notPrincipals:
                  - "cluster.local/ns/my-ns/sa/my-service"
  allow-internal:
    spec:
      action: ALLOW
      selector:
        matchLabels:
          app: my-svc
      rules:
        - from:
            - source:
                principals:
                  - "cluster.local/ns/my-ns/sa/my-client"

istioPeerAuthentications:
  default:
    spec:
      mtls:
        mode: STRICT
  legacy-svc:
    spec:
      selector:
        matchLabels:
          app: legacy
      mtls:
        mode: PERMISSIVE
```

### EnvoyFilters

EnvoyFilter uses `spec:` passthrough — all CRD fields go under `spec:`. This includes `configPatches`, `workloadSelector`, `priority`, and any other EnvoyFilter-specific fields.

```yaml
istioEnvoyFilters:
  add-header:
    labels:
      app.kubernetes.io/component: envoyfilter
    spec:
      priority: 10
      workloadSelector:
        labels:
          app: my-app
      configPatches:
        - applyTo: HTTP_FILTER
          match:
            context: SIDECAR_INBOUND
          patch:
            operation: INSERT_FIRST
            value:
              name: envoy.filters.http.lua
              typed_config:
                '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                inlineCode: |
                  function envoy_on_request(request_handle)
                    request_handle:headers():add("X-Custom-Header", "value")
                  end
```

---

## cert-manager

All cert-manager resources support `labels:` and `annotations:` per entry.

```yaml
certificates:
  my-tls:
    labels:
      team: platform
    annotations:
      cert-manager.io/issue-temporary-certificate: "true"
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

issuers:
  internal-ca:
    labels:
      team: platform
    ca:
      secretName: internal-ca-secret
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
      commonUpdateSettings:
        updateStrategy: newest-build
        allowTags: 'regexp:^\d+\.\d+\.\d+$'
      manifestTargets:
        helm:
          name: deployment.image
          tag: deployment.imageTag
  writeBackConfig:
    method: argocd
```

### Finding applicationName

`applicationName` must match the ArgoCD Application name exactly — this is how Image Updater knows which app to write image tags back to. Get it wrong and updates silently stop (Image Updater won't error loudly).

The ArgoCD Application name is whatever the `metadata.name` is on the ArgoCD `Application` resource that deploys this chart. Check your ArgoCD UI or run:

```bash
kubectl get applications -n argocd
```

If your ArgoCD Application manifests are generated by a higher-level chart or controller, the name follows whatever naming convention that generator uses. Set `applicationName` to exactly that value.

### Job workloads and Image Updater

On fresh application install or Application recreation, the initial sync may fail when a `job:` block uses `imageTag: ""`. Image Updater operates on its own independent poll cycle — when the Job is created during PreSync, Image Updater may not have written the correct tag yet. Kubernetes Jobs have an immutable spec, so the Job cannot be patched once created with a wrong image.

With `selfHeal: true` the Application recovers automatically in couple of minutes once `activeDeadlineSeconds` expires and Image Updater writes the correct tag. Manually terminating the sync and re-syncing skips the wait.

This only affects fresh installs and Application recreations. Regular chart version upgrades and values changes are unaffected — Image Updater's tag persists in `spec.sources[n].helm.parameters` across syncs.

To handle Job immutability on re-sync and preserve the last completed Job pod for log access, add these annotations to the `job:` block:

```yaml
job:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-1"
    argocd.argoproj.io/sync-options: Replace=true,Force=true
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookFailed
```

`Replace=true` makes ArgoCD delete-and-recreate the Job instead of patching it when the image tag changes. Without a `hook-delete-policy`, the completed Job pod persists between deploys so developers can inspect logs from the last run.

---

## Global Settings

```yaml
defaultImagePullPolicy: IfNotPresent
imagePullSecrets:
  - acr-pull-secret
nameOverride: ""        # Override the chart name used in resource name generation and labels

usePredefinedAffinity: true
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
    spec:
      podSelector: {}
      policyTypes: [Ingress, Egress]
```

---

## NetworkPolicy

Kubernetes NetworkPolicy resources use `spec:` passthrough — all NetworkPolicy fields go under `spec:`.

```yaml
networkPolicies:
  # Deny all ingress traffic (default deny)
  deny-all:
    labels:
      team: platform
    annotations:
      app.example.com/policy: deny-all
    spec:
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress

  # Allow specific ingress from a CIDR range
  allow-frontend:
    spec:
      podSelector:
        matchLabels:
          app: frontend
      ingress:
        - from:
            - ipBlock:
                cidr: 10.0.0.0/8
                except:
                  - 10.96.0.0/12
          ports:
            - port: "8080"
              protocol: TCP
      policyTypes:
        - Ingress

  # Allow egress to a specific namespace + pod combination
  allow-egress-db:
    spec:
      podSelector:
        matchLabels:
          app: my-app
      egress:
        - to:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: database
              podSelector:
                matchLabels:
                  app: db
          ports:
            - port: "5432"
              protocol: TCP
      policyTypes:
        - Egress
```

Supported fields: `name`, `labels`, `annotations`, `disabled`, `spec` (passthrough — all NetworkPolicy spec fields).

---

## Chart Maintenance

### Required tooling

| Tool | Repo |
|---|---|
| [Helm](https://helm.sh/docs/intro/install/) | https://github.com/helm/helm |
| [helm-unittest](https://github.com/helm-unittest/helm-unittest) | https://github.com/helm-unittest/helm-unittest |
| [helm-docs](https://github.com/norwoodj/helm-docs) | https://github.com/norwoodj/helm-docs |
| [helmfmt](https://github.com/digitalstudium/helmfmt) | https://github.com/digitalstudium/helmfmt |
| [kubeconform](https://github.com/yannh/kubeconform) | https://github.com/yannh/kubeconform |
| [pre-commit](https://pre-commit.com/) | https://github.com/pre-commit/pre-commit |
| [yamllint](https://yamllint.readthedocs.io/) | https://github.com/adrienverge/yamllint |

After installing, enable the git hooks once per clone:

```bash
pre-commit install
```

The hooks run `helmfmt` and `helm-docs` automatically on every commit, keeping formatting and README in sync without manual intervention.

### Verification commands

```bash
# Lint
helm lint universal-chart/ --strict

# Unit tests
helm unittest universal-chart/ --strict --file 'tests/*.yaml'

# Render smoke test (validates values against schema)
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml

# Schema validation
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.33.6 \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json'

# Regenerate README after any values.yaml change
helm-docs --chart-search-root universal-chart/ --sort-values-order=file
cp universal-chart/README.md README.md
```

All five must pass before merging a PR.

### Version bumping

Every change to chart templates, values, or schema should be accompanied by a `version:` bump in `Chart.yaml`. Even a one-line fix. This keeps the release history honest — a version number that didn't change signals "nothing significant happened", and silently shipping unreleased template changes into a future bump makes it impossible to know what a given version actually contains. Bump early, bump often. The release pipeline skips already-published versions, so there is no cost to bumping.
Also, if this maintenance hygiene is honored, chart [Release](https://github.com/OrigoSoftwareSolutions/universal-chart/releases) page will be populated with all changes neatly instead of having to chase diffs between releases manually.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| defaultImagePullPolicy | string | `"IfNotPresent"` | Fallback image pull policy. One of: `Always`, `IfNotPresent`, `Never`. |
| imagePullSecrets | list | `[]` | Image pull secret names referenced in every pod spec. Secrets must be pre-created in the namespace. |
| diagnosticMode | object | `{"args":["infinity"],"command":["sleep"],"enabled":false}` | Diagnostic mode — overrides command/args on main containers only (init containers are not affected). |
| diagnosticMode.enabled | bool | `false` | Enable diagnostic mode globally. |
| diagnosticMode.command | list | `["sleep"]` | Command override applied to every container. |
| diagnosticMode.args | list | `["infinity"]` | Args override applied to every container. |
| usePredefinedAffinity | bool | `true` | Use the chart's built-in pod affinity/anti-affinity rules. |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration. |
| nodeAffinityPreset.type | string | `""` | Affinity type. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset.key | string | `""` | Node label key to match (e.g. `kubernetes.io/e2e-az-name`). |
| nodeAffinityPreset.values | list | `[]` | Node label values to match. |
| deployment | object | `{}` | Kubernetes Deployment.  Only one per release. Single-container shorthand: set `image:` at workload level instead of `containers:`. `ports:` (map form) auto-creates containerPorts. Use the full `containers:` list for multi-container workloads. |
| statefulset | object | `{}` | Kubernetes StatefulSet.  Only one per release. |
| daemonset | object | `{}` | Kubernetes DaemonSet.  Only one per release. |
| job | object | `{}` | Kubernetes Job (non-hook).  Only one per release. |
| cronJob | object | `{}` | Kubernetes CronJob.  Only one per release. |
| service | object | `{}` | Kubernetes Service.  Only one per release. |
| httpRoutes | object | `{}` | Gateway API HTTPRoute resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| networkPolicies | object | `{}` | Kubernetes NetworkPolicy resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| configMaps | object | `{}` | Kubernetes ConfigMap resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| storageClasses | object | `{}` | Kubernetes StorageClass resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| persistentVolumes | object | `{}` | Kubernetes PersistentVolume resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| pvc | object | `{}` | Kubernetes PersistentVolumeClaim.  Only one per release. |
| hpa | object | `{}` | Kubernetes HorizontalPodAutoscaler (autoscaling/v2).  Only one per release. When `hpa` is set, `replicas` is omitted from the Deployment/StatefulSet spec so HPA has full ownership of the replica count — prevents GitOps tools (e.g. ArgoCD) from showing a perpetual diff on `spec.replicas`. Cannot be used together with `vpa` — enabling both fails with an error at render time. |
| vpa | object | `{}` | Kubernetes VerticalPodAutoscaler (autoscaling.k8s.io/v1).  Only one per release. Adjusts CPU/memory requests on existing pods without changing the replica count. Well-suited for single-replica workloads where horizontal scaling is not desired. Cannot be used together with `hpa` — enabling both fails with an error at render time. |
| pdb | object | `{}` | Kubernetes PodDisruptionBudget.  Only one per release. |
| serviceAccount | list | `[]` | Kubernetes ServiceAccount(s). List — each item creates one ServiceAccount. Supports Role/ClusterRole per item. |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioGateways | object | `{}` | Istio Gateway resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. `servers` is a map (keys are logical names) so entries from multiple value files are merged by Helm — enabling per-project gateway server definitions. |
| istioVirtualServices | object | `{}` | Istio VirtualService resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioDestinationRules | object | `{}` | Istio DestinationRule resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioEnvoyFilters | object | `{}` | Istio EnvoyFilter resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| externalSecrets | object | `{}` | External Secrets Operator ExternalSecret resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterSecretStores | object | `{}` | External Secrets Operator ClusterSecretStore resources (cluster-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterExternalSecrets | object | `{}` | External Secrets Operator ClusterExternalSecret resources (cluster-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| certificates | object | `{}` | cert-manager Certificate resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| issuers | object | `{}` | cert-manager Issuer resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterIssuers | object | `{}` | cert-manager ClusterIssuer resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| imageUpdater | object | `{}` | Argo CD Image Updater.  Only one per release. |
| extraDeploy | object | `{}` | Raw Kubernetes manifests to deploy alongside chart resources. Supports template expressions. |
