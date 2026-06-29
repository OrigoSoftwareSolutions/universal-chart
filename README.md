# Origo Universal Helm Chart

![Version: 1.9.95](https://img.shields.io/badge/Version-1.9.95-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

One Helm chart, designed for one workload per release. Define your Kubernetes resources — Deployment (or StatefulSet, DaemonSet, Job, CronJob) plus supporting resources (Service, HPA, ServiceAccount, ExternalSecret, Istio configs, and more) — in a single values file.

---

## Supported Resources

| Core Workload | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PVC | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | StorageClass / PV | PrometheusRule (via job / cronJob) |
| HPA / PDB | ServiceMonitor / NetworkPolicy | ServiceAccount | ImageUpdater (Argo CD) |
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

Each item supports: `name`, `labels`, `annotations`, `automountServiceAccountToken`, `imagePullSecrets`, `secrets`, `role`, `clusterRole`.

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
      - port:
          number: 443
          name: https
          protocol: HTTPS
        hosts:
          - myapp.example.com

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

---

## Global Settings

```yaml
defaultImagePullPolicy: IfNotPresent
imagePullSecrets:
  - acr-pull-secret
nameOverride: ""        # Override chart name in resource labels

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
      namespace: {{ .Release.Namespace | quote }}
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
helm-docs --chart-search-root universal-chart/ -o ../README.md
```

All five must pass before merging a PR.

### Version bumping

Every change to chart templates, values, or schema should be accompanied by a `version:` bump in `Chart.yaml`. Even a one-line fix. This keeps the release history honest — a version number that didn't change signals "nothing significant happened", and silently shipping unreleased template changes into a future bump makes it impossible to know what a given version actually contains. Bump early, bump often. The release pipeline skips already-published versions, so there is no cost to bumping.
Also, if this maintenance hygiene is honored, chart [Release](https://github.com/OrigoSoftwareSolutions/universal-chart/releases) page will be populated with all changes neatly instead of having to chase diffs between releases manually.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| certificates | object | `{}` | cert-manager Certificate resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterExternalSecrets | object | `{}` | External Secrets Operator ClusterExternalSecret resources (cluster-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterIssuers | object | `{}` | cert-manager ClusterIssuer resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| clusterSecretStores | object | `{}` | External Secrets Operator ClusterSecretStore resources (cluster-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| configMaps | object | `{}` | Kubernetes ConfigMap resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| cronJob | object | `{}` | Kubernetes CronJob.  Only one per release. |
| daemonset | object | `{}` | Kubernetes DaemonSet.  Only one per release. |
| defaultImagePullPolicy | string | `"IfNotPresent"` | Fallback image pull policy. One of: `Always`, `IfNotPresent`, `Never`. |
| deployment | object | `{}` | Kubernetes Deployment.  Only one per release. Single-container shorthand: set `image:` at workload level instead of `containers:`. `ports:` (map form) auto-creates containerPorts. Use the full `containers:` list for multi-container workloads. |
| diagnosticMode | object | `{"args":["infinity"],"command":["sleep"],"enabled":false}` | Diagnostic mode — overrides command/args on main containers only (init containers are not affected). |
| diagnosticMode.args | list | `["infinity"]` | Args override applied to every container. |
| diagnosticMode.command | list | `["sleep"]` | Command override applied to every container. |
| diagnosticMode.enabled | bool | `false` | Enable diagnostic mode globally. |
| externalSecrets | object | `{}` | External Secrets Operator ExternalSecret resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| extraDeploy | object | `{}` | Raw Kubernetes manifests to deploy alongside chart resources. Supports template expressions. |
| hpa | object | `{}` | Kubernetes HorizontalPodAutoscaler (autoscaling/v2).  Only one per release. |
| httpRoutes | object | `{}` | Gateway API HTTPRoute resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| imagePullSecrets | list | `[]` | Image pull secret names referenced in every pod spec. Secrets must be pre-created in the namespace. |
| imageUpdater | object | `{}` | Argo CD Image Updater.  Only one per release. |
| issuers | object | `{}` | cert-manager Issuer resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioDestinationRules | object | `{}` | Istio DestinationRule resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioEnvoyFilters | object | `{}` | Istio EnvoyFilter resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioGateways | object | `{}` | Istio Gateway resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| istioVirtualServices | object | `{}` | Istio VirtualService resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| job | object | `{}` | Kubernetes Job (non-hook).  Only one per release. |
| networkPolicies | object | `{}` | Kubernetes NetworkPolicy resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration. |
| nodeAffinityPreset.key | string | `""` | Node label key to match (e.g. `kubernetes.io/e2e-az-name`). |
| nodeAffinityPreset.type | string | `""` | Affinity type. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset.values | list | `[]` | Node label values to match. |
| pdb | object | `{}` | Kubernetes PodDisruptionBudget.  Only one per release. |
| persistentVolumes | object | `{}` | Kubernetes PersistentVolume resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| pvc | object | `{}` | Kubernetes PersistentVolumeClaim.  Only one per release. |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| service | object | `{}` | Kubernetes Service.  Only one per release. |
| serviceAccount | list | `[]` | Kubernetes ServiceAccount(s). List — each item creates one ServiceAccount. Supports Role/ClusterRole per item. |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| statefulset | object | `{}` | Kubernetes StatefulSet.  Only one per release. |
| storageClasses | object | `{}` | Kubernetes StorageClass resources (cluster-scoped, no namespace). Each key creates one instance; name defaults to `{release-name}-{key}`, overridable per entry with a `name:` field. |
| usePredefinedAffinity | bool | `true` | Use the chart's built-in pod affinity/anti-affinity rules. |
