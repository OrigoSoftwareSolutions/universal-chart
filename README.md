# Origo Universal Helm Chart

![Version: 1.6.0](https://img.shields.io/badge/Version-1.6.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

One Helm chart for everything. Instead of maintaining a separate chart per service, define all your Kubernetes resources — Deployments, CronJobs, Services, ExternalSecrets, Istio configs, and more — in a single values file.

## Supported Resources

| Core Workloads | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret / ClusterExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PersistentVolumeClaim | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | ServiceAccount | PrometheusRule |
| Helm Hooks | ServiceMonitor | PersistentVolume | ImageUpdater (Argo CD) |
| HPA / PDB | | | Istio DestinationRule / PeerAuthentication / AuthorizationPolicy |

## Install

```bash
helm install my-release oci://ghcr.io/origosoftwaresolutions/universal-chart \
  --version 1.6.0 \
  -f my-values.yaml
```

## Minimal Starter

The absolute minimum to deploy a working container:

```yaml
deployments:
  myapp:
    image: registry.example.com/myapp
    imageTag: "1.0.0"
```

That's it. This creates a Deployment with 1 replica, a ClusterIP Service (if you add `ports:`), hardened security contexts, resource requests, and pod anti-affinity — all from the chart's built-in defaults. Add features as you need them.

---

## Quick Start — Realistic Web Service

This single values file creates a Deployment, Service, HPA, PDB, CronJob, ExternalSecret, and environment variables:

```yaml
# ── Deployment with auto-generated Service ──
deployments:
  api:
    image: registry.example.com/my-api
    imageTag: "1.4.2"
    replicas: 2
    ports:
      http: 8080
    healthCheck:
      path: /healthz
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        memory: 512Mi

# ── Autoscaling ──
hpas:
  api:
    scaleTargetRef:
      name: api
    minReplicas: 2
    maxReplicas: 8
    targetCPU: 70

# ── Availability ──
pdbs:
  api:
    minAvailable: 1

# ── Scheduled work ──
cronJobs:
  cleanup:
    schedule: "0 3 * * *"
    image: registry.example.com/my-api
    imageTag: "1.4.2"
    command: ["python", "manage.py", "cleanup", "--older-than", "30d"]

# ── Secrets from AWS Secrets Manager ──
secretStores:
  aws:
    spec:
      provider:
        aws:
          service: SecretsManager
          region: eu-west-1

externalSecrets:
  api-secrets:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws
        kind: SecretStore
      target:
        name: api-secrets
      data:
        - secretKey: DB_PASSWORD
          remoteRef:
            key: prod/api
            property: db_password

# ── Environment variables ──
envs:
  LOG_LEVEL: info
  API_BASE_URL: https://api.example.com

secretEnvs:
  SESSION_SECRET: change-me-in-real-life
```

Everything below explains each feature in detail with copy-pasteable examples.

---

## How It Works

### Mental model

Think of this chart as a **resource factory**. Each top-level key in your values file (`deployments`, `cronJobs`, `services`, …) is a resource type. Each sub-key under it becomes one Kubernetes resource named `<release>-<key>` (or `<releasePrefix>-<key>` if set):

```
values.yaml                          Kubernetes
─────────                            ──────────
deployments:
  api:          ──────────────────►   Deployment  "my-release-api"
  worker:       ──────────────────►   Deployment  "my-release-worker"

cronJobs:
  cleanup:      ──────────────────►   CronJob     "my-release-cleanup"

services:
  cache:        ──────────────────►   Service     "my-release-cache"
```

### What gets created automatically

| You write… | Chart also creates… |
|---|---|
| `deployments.api.ports: {http: 8080}` | A matching ClusterIP **Service** with port `http:8080` |
| `deployments.api.healthCheck: {path: /healthz}` | **Startup**, **liveness**, and **readiness** probes |
| `pvcs.data.mountPath: /data` | A **PVC**, a pod **volume**, and a **volumeMount** in every container |
| `serviceAccounts.sa.role: {…}` | A **Role** + **RoleBinding** (or ClusterRole + ClusterRoleBinding) |
| `cronJobs.etl.commandDurationAlert: 1800` | A **PrometheusRule** that fires if the job exceeds 30 min |

### The 3-tier defaults cascade

Settings are merged in order of increasing specificity. A more-specific value always wins:

```
defaults:              ← applied to ALL workloads
  └─ deploymentsGeneral:  ← applied to all Deployments
       └─ deployments.api:   ← this specific Deployment
```

Example: `defaults.resources` sets baseline CPU/memory → `deploymentsGeneral.replicas` sets replica count for all Deployments → `deployments.api.replicas` overrides it for just `api`.

Available `*General` blocks: `deploymentsGeneral`, `statefulSetsGeneral`, `daemonSetsGeneral`, `cronJobsGeneral`, `jobsGeneral`, `hooksGeneral`, `serviceAccountsGeneral`.

### Single-container shorthand vs full form

Most workloads have one container. The chart lets you skip the `containers:` list and set `image`, `ports`, `resources`, `healthCheck`, `command`, etc. directly on the workload:

```yaml
# Shorthand (one container) — chart names the container after the workload key
deployments:
  api:
    image: myapp
    imageTag: "1.0.0"
    ports:
      http: 8080           # map form → auto-creates Service
    healthCheck:
      path: /healthz       # → startup + liveness + readiness probes
    resources:
      requests: {cpu: 100m, memory: 128Mi}

# Full form (multi-container) — you control container names
deployments:
  api:
    containers:
      - name: app
        image: myapp
        imageTag: "1.0.0"
        ports:
          - name: http
            containerPort: 8080   # list form → no auto Service
      - name: sidecar
        image: envoy
        imageTag: "v1.28"
```

> **Key difference**: `ports:` as a **map** (`{http: 8080}`) triggers auto-Service creation and the `healthCheck` shorthand. `ports:` as a **list** (standard K8s format) does not.

### CRD resources: thin passthrough

For CRD-based resources (ExternalSecret, HTTPRoute, SecretStore, Certificate, etc.), the chart uses thin passthrough — you write `spec:` and it goes directly to the Kubernetes resource unchanged:

```yaml
secretStores:
  aws:
    spec:                    # ← passed through to the K8s resource as-is
      provider:
        aws:
          service: SecretsManager
          region: eu-west-1
```

No abstraction layers, no surprises. Whatever you put in `spec:` is what Kubernetes sees.

---

## Workloads

### Deployments

#### Single-container shorthand

The most common pattern. Set `image`, `ports`, `resources`, `healthCheck` directly on the workload — no `containers:` list needed.

```yaml
deployments:
  api:
    image: registry.example.com/my-api
    imageTag: "2.0.0"
    replicas: 3
    ports:
      http: 8080
      metrics: 9090
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        memory: 256Mi
    healthCheck:
      path: /healthz
      port: 8080            # default: 8080
    command: ["node", "server.js"]
```

This creates:
- A Deployment with one container
- A ClusterIP Service with ports `http:8080` and `metrics:9090` (auto-generated from `ports:`)
- Startup, liveness, and readiness probes (all from one `healthCheck`)

#### Suppress or customize the auto-generated Service

```yaml
deployments:
  worker:
    image: my-worker
    imageTag: "1.0.0"
    ports:
      http: 8080
    service: false  # no Service created

  api:
    image: my-api
    imageTag: "1.0.0"
    ports:
      http: 8080
    service:
      type: NodePort
      annotations:
        external-dns.alpha.kubernetes.io/hostname: api.example.com
```

#### Multi-container workloads

When you need sidecars or multiple containers, use the full `containers:` list:

```yaml
deployments:
  web:
    replicas: 2
    containers:
      - name: app
        image: my-app
        imageTag: "1.0.0"
        ports:
          - name: http
            containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
      - name: sidecar
        image: envoyproxy/envoy
        imageTag: "v1.28"
        ports:
          - name: admin
            containerPort: 9901
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
```

#### Health check shorthand

A single `healthCheck` generates startup, liveness, **and** readiness probes:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    healthCheck:
      path: /healthz          # HTTP GET path
      port: 8080              # default: 8080
      periodSeconds: 10       # default: 10
      failureThreshold: 3     # default: 3
      initialDelaySeconds: 0  # default: 0
```

For full control, set `livenessProbe`, `readinessProbe`, `startupProbe` directly on the container.

### StatefulSets

Same shorthand as Deployments. Adds `volumeClaimTemplates` and uses `updateStrategy` instead of `strategy`. The `serviceName` defaults to the workload key name (matching the auto-generated Service):

```yaml
statefulSets:
  postgres:
    image: postgres
    imageTag: "16"
    replicas: 1
    # serviceName: my-headless-svc  # override if you need a custom governing service
    ports:
      pg: 5432
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
    volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 50Gi
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data
```

> **Note:** The chart auto-generates a standard `ClusterIP` Service when `ports:` is set on a StatefulSet (same as Deployments). If your pods need stable DNS names (e.g. `postgres-0.postgres.ns.svc`), create a separate headless Service (`clusterIP: None`) in the `services:` block and point `serviceName` to it.

### DaemonSets

Run one pod per node. No `replicas` field. Uses `updateStrategy`:

```yaml
daemonSets:
  log-agent:
    image: fluent/fluent-bit
    imageTag: "3.0"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi
    volumes:
      - name: varlog
        type: hostPath
        path: /var/log
    volumeMounts:
      - name: varlog
        mountPath: /var/log
        readOnly: true
```

### CronJobs

```yaml
cronJobs:
  nightly-report:
    schedule: "0 2 * * *"
    image: registry.example.com/reporter
    imageTag: "1.0.0"
    command: ["python", "generate_report.py"]
    resources:
      requests:
        cpu: 100m
        memory: 256Mi

  db-backup:
    schedule: "0 */6 * * *"
    singleOnly: true          # shorthand for concurrencyPolicy: Forbid
    image: postgres
    imageTag: "16"
    command: ["pg_dump", "-h", "$DB_HOST", "mydb", "|", "gzip", ">", "/backup/dump.sql.gz"]
    commandDurationAlert: 3600  # PrometheusRule fires if job runs > 1 hour
```

### Jobs

```yaml
jobs:
  seed-data:
    image: registry.example.com/my-api
    imageTag: "1.0.0"
    command: ["python", "manage.py", "seed"]
    backoffLimit: 3
```

### Helm Hooks

Pre/post-install/upgrade jobs that run during Helm lifecycle:

```yaml
hooks:
  db-migrate:
    containers:
      - image: registry.example.com/my-api
        imageTag: "1.0.0"
        command:
          - python
          - manage.py
          - migrate
    kind: pre-upgrade              # default: pre-install,pre-upgrade
    weight: "-5"                   # default: 5
    deletePolicy: before-hook-creation  # default: before-hook-creation
```

---

## Networking

### Services

Auto-generated from `ports:` on workloads (see above). For standalone Services:

```yaml
services:
  external-db:
    type: ExternalName
    externalName: db.example.com
    ports:
      - name: pg
        port: 5432
```

### HTTPRoute (Gateway API)

Thin passthrough — `spec:` goes directly to the Kubernetes resource:

```yaml
httpRoutes:
  api:
    spec:
      parentRefs:
        - name: main-gateway
          namespace: istio-ingress
      hostnames:
        - api.example.com
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: api
              port: 8080
```

### Istio VirtualService

```yaml
istioVirtualServices:
  api:
    gateways:
      - main-gateway
    hosts:
      - api.example.com
    http:
      - match:
          - uri:
              prefix: /v1
        route:
          - destination:
              host: api
              port:
                number: 8080
```

### Istio Gateway

```yaml
istioGateways:
  main:
    selector:
      istio: ingressgateway
    servers:
      - port:
          number: 443
          name: https
          protocol: HTTPS
        tls:
          mode: SIMPLE
          credentialName: tls-cert
        hosts:
          - "*.example.com"
```

### Other Istio CRDs

The chart also supports Istio DestinationRule, PeerAuthentication, and AuthorizationPolicy as thin-passthrough CRDs. Values keys: `istioDestinationRules`, `istioPeerAuthentications`, `istioAuthorizationPolicies`.

---

## Storage & Config

### ConfigMaps

```yaml
configMaps:
  app-config:
    data:
      config.yaml: |
        database:
          host: postgres
          port: 5432
      FEATURE_FLAG: "true"
```

### Secrets

```yaml
secrets:
  api-keys:
    data:
      API_KEY: my-secret-key
      # Prefix with b64: to pass raw base64 (avoids double-encoding)
      CERT: "b64:LS0tLS1CRUdJTi..."
```

### PersistentVolumeClaims

PVCs are **auto-mounted** as volumes into every Deployment, StatefulSet, and DaemonSet. Add `mountPath` to also inject a `volumeMount`:

```yaml
pvcs:
  app-data:
    accessModes:
      - ReadWriteOnce
    size: 10Gi
    storageClassName: gp3
    mountPath: /data          # auto-mount into every container
    subPath: app              # optional: sub-directory within the volume
    readOnly: false           # optional: default false

  shared-cache:
    accessModes:
      - ReadWriteMany
    size: 5Gi
    # no mountPath = volume is added but not mounted (manual volumeMount needed)

  old-pvc:
    disabled: true            # skipped entirely — no volume, no mount
    accessModes:
      - ReadWriteOnce
    size: 1Gi
```

Hooks, Jobs, and CronJobs are excluded from auto-mounting.

### Typed Volumes

Instead of raw Kubernetes volume specs, use simplified `type` + `name`:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    volumes:
      - name: config
        type: configMap
        configMapName: app-config
      - name: certs
        type: secret
        secretName: tls-certs
      - name: tmp
        type: emptyDir
      - name: data
        type: pvc
        claimName: app-data
    volumeMounts:
      - name: config
        mountPath: /etc/app
      - name: certs
        mountPath: /certs
        readOnly: true
      - name: tmp
        mountPath: /tmp
```

---

## Environment Variables

### Global envs (injected into all workloads)

```yaml
# Plain text → ConfigMap + envFrom
envs:
  LOG_LEVEL: info
  API_URL: https://api.example.com

# Secrets → Secret + envFrom
secretEnvs:
  DB_PASSWORD: s3cret
  API_KEY: abc123

# For multiline values or special characters, use the string variants:
envsString: |
  MULTILINE_CONFIG: |
    line1
    line2

secretEnvsString: |
  PRIVATE_KEY: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
```

### Per-workload env injection

Each workload can pull envs from existing ConfigMaps/Secrets:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"

    # Inject entire ConfigMap/Secret via envFrom
    envConfigmaps:
      - app-config
      - feature-flags
    envSecrets:
      - api-credentials

    # Cherry-pick individual keys
    envsFromConfigmap:
      DATABASE_URL:
        name: db-config
        key: url
    envsFromSecret:
      DB_PASSWORD:
        name: db-secret
        key: password

    # Inline env entries
    env:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
```

### Base64 shorthand

Values prefixed with `b64:` skip double-encoding in Secrets and auto-decode in ConfigMaps:

```yaml
secrets:
  certs:
    data:
      ca.crt: "b64:LS0tLS1CRUdJTi..."  # stored as-is (already base64)
      token: my-plain-token               # auto-encoded to base64
```

---

## Autoscaling & Availability

### HorizontalPodAutoscaler

```yaml
hpas:
  api:
    scaleTargetRef:
      name: api               # references Deployment name
      # kind: Deployment      # optional, defaults to Deployment
    minReplicas: 2
    maxReplicas: 10
    targetCPU: 70             # percentage
    targetMemory: 80          # percentage
    behavior:                 # optional: fine-grained scaling behavior
      scaleDown:
        stabilizationWindowSeconds: 300
```

### PodDisruptionBudget

```yaml
pdbs:
  api:
    minAvailable: 1
    # OR
    # maxUnavailable: 25%
    unhealthyPodEvictionPolicy: IfHealthyBudget  # optional: IfHealthyBudget or AlwaysAllow
    extraSelectorLabels:      # additional labels for pod selection
      app: api
```

---

## Identity & Access

### ServiceAccount with auto-RBAC

Define `role:` or `clusterRole:` inside a ServiceAccount to auto-create Role/ClusterRole and their bindings:

```yaml
serviceAccounts:
  app-sa:
    # Create a Role + RoleBinding
    role:
      name: app-role
      rules:
        - apiGroups:
            - ""
          resources:
            - pods
            - services
          verbs:
            - get
            - list
            - watch
        - apiGroups:
            - apps
          resources:
            - deployments
          verbs:
            - get
            - list

    # Bind to an existing ClusterRole (no rules = binding only)
    clusterRole:
      name: view  # built-in K8s ClusterRole
```

Use `defaults.serviceAccountName: app-sa` or set `serviceAccountName` per workload to assign the ServiceAccount.

---

## Monitoring

### ServiceMonitor (Prometheus)

```yaml
serviceMonitors:
  api:
    endpoints:
      - port: metrics
        path: /metrics
        interval: 30s
    selector:
      matchLabels:
        app.kubernetes.io/name: api
```

### Job/CronJob Duration Alerts

Auto-creates a PrometheusRule when execution exceeds a threshold:

```yaml
cronJobs:
  etl:
    schedule: "0 * * * *"
    image: my-etl
    imageTag: "1.0.0"
    command: ["python", "etl.py"]
    commandDurationAlert: 1800  # fires warning if job runs > 30 minutes
```

---

## CRD Resources

### ExternalSecret (External Secrets Operator)

```yaml
secretStores:
  aws:
    spec:
      provider:
        aws:
          service: SecretsManager
          region: eu-west-1
          auth:
            jwt:
              serviceAccountRef:
                name: eso-sa

externalSecrets:
  db-credentials:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws
        kind: SecretStore
      target:
        name: db-credentials
      data:
        - secretKey: password
          remoteRef:
            key: prod/database
            property: password
        - secretKey: username
          remoteRef:
            key: prod/database
            property: username

# Cluster-scoped variants
clusterSecretStores:
  global-aws:
    spec:
      provider:
        aws:
          service: SecretsManager
          region: eu-west-1

clusterExternalSecrets:
  shared-config:
    spec:
      refreshInterval: 24h
      secretStoreRef:
        name: global-aws
        kind: ClusterSecretStore
      target:
        name: shared-config
      data: []
```

### Certificate (cert-manager)

```yaml
clusterIssuers:
  letsencrypt-prod:
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: devops@example.com
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
          - http01:
              ingress:
                class: istio

certificates:
  api-tls:
    spec:
      secretName: api-tls
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
        - api.example.com
        - "*.api.example.com"
```

### ImageUpdater (Argo CD)

Configures automatic image updates for Argo CD applications:

```yaml
imageUpdaters:
  my-app:
    applicationName: my-argocd-app
    # namespace: argocd       # default: argocd
    images:
      - alias: api
        imageName: registry.example.com/my-api
        updateStrategy: newest-build    # latest | newest-build | alphabetical | digest
        allowTags: 'regexp:^\d+\.\d+\.\d+-main-[a-z0-9]+-\d+$'
      - alias: worker
        imageName: registry.example.com/my-worker
        updateStrategy: latest
        ignoreTags:
          - dev
          - latest
    writeBackConfig:
      method: argocd    # or git
      # git:
      #   branch: main
```

---

## Chart Behavior

### 3-Tier Defaults Cascade

Settings merge in order: `defaults` (global) → `deploymentsGeneral` (kind-level) → per-instance. Set shared config once, override where needed:

```yaml
defaults:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  podAnnotations:
    sidecar.istio.io/inject: "true"

deploymentsGeneral:
  replicas: 2                 # all Deployments get 2 replicas unless overridden

deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    # inherits: 2 replicas, 100m/128Mi resources, istio sidecar annotation

  heavy-worker:
    image: my-worker
    imageTag: "1.0.0"
    replicas: 1               # overrides deploymentsGeneral
    resources:
      requests:
        cpu: 1
        memory: 2Gi  # overrides defaults
```

Available `*General` blocks: `deploymentsGeneral`, `statefulSetsGeneral`, `daemonSetsGeneral`, `cronJobsGeneral`, `jobsGeneral`, `hooksGeneral`, `serviceAccountsGeneral`.

### Security Defaults

Every pod gets hardened security contexts out of the box:

```yaml
# These are the defaults — you don't need to set them
defaults:
  podSecurityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

Override per-workload. Use `podSecurityContext` for pod-level settings, `containerSecurityContext`
for single-container shorthand, or `containers[].securityContext` when you use the full
multi-container form:

```yaml
deployments:
  legacy-app:
    image: old-app
    imageTag: "1.0.0"
    podSecurityContext:
      runAsNonRoot: false
    containerSecurityContext:
      readOnlyRootFilesystem: false
```

### Image Pull Secrets

Pull images from private registries by listing secret names at the top level. Every pod spec in every workload gets these secrets injected:

```yaml
imagePullSecrets:
  - my-registry-secret
  - other-registry-secret
```

For additional per-workload secrets, use `defaults.extraImagePullSecrets` or the workload-level `extraImagePullSecrets` field — they all merge together. The older `imagePullSecrets` field on workloads still works but is deprecated in favor of `extraImagePullSecrets` and will be removed in 3.0.

### Affinity Presets

Built-in pod affinity/anti-affinity rules are on by default:

```yaml
podAffinityPreset: soft       # soft | hard | "" (disabled)
podAntiAffinityPreset: soft
nodeAffinityPreset:
  type: hard                  # soft | hard | ""
  key: topology.kubernetes.io/zone
  values:
    - eu-west-1a
    - eu-west-1b
```

Disable per-workload with `usePredefinedAffinity: false`, or supply a custom `affinity:` block.

### Workload Isolation Labels

Every Deployment, StatefulSet, and DaemonSet automatically receives an `app.kubernetes.io/component` label derived from the workload's key name. This label is added to `spec.selector.matchLabels`, pod template labels, auto-generated Service selectors, and pod affinity/anti-affinity rules.

This ensures that multiple workloads in the same release are fully isolated — each controller manages only its own pods, each auto-generated Service routes only to the correct workload, and affinity rules target same-workload pods rather than all pods in the release.

```yaml
deployments:
  api:       # → app.kubernetes.io/component: api
    image: my-api
    imageTag: "1.0.0"
    ports:
      http: 8080
  worker:    # → app.kubernetes.io/component: worker
    image: my-worker
    imageTag: "1.0.0"
```

The resulting selector for each Deployment:

```yaml
# api Deployment
selector:
  matchLabels:
    app.kubernetes.io/name: my-release
    app.kubernetes.io/instance: my-release
    app.kubernetes.io/component: api    # ← unique per workload

# worker Deployment
selector:
  matchLabels:
    app.kubernetes.io/name: my-release
    app.kubernetes.io/instance: my-release
    app.kubernetes.io/component: worker  # ← unique per workload
```

### Diagnostic Mode

Override **all** containers with `sleep infinity` and suppress all health probes — useful for debugging crash-looping pods:

```yaml
diagnosticMode:
  enabled: true
  # command:
  #   - sleep     # default
  # args:
  #   - infinity     # default
```

### Graceful Shutdown

Inject a `sleep N` preStop hook into every container:

```yaml
defaults:
  preStopSleep: 5  # seconds — allows in-flight requests to drain before SIGTERM
```

### Disable Without Deleting

Any resource instance accepts `disabled: true` to suppress rendering. The config stays in your values file for easy re-enabling:

```yaml
deployments:
  api:
    disabled: true    # skipped entirely — no Deployment, no Service
    image: my-api
    imageTag: "1.0.0"
    ports:
      http: 8080
```

### Template Expressions in Values

Go template expressions work anywhere in string values:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    podAnnotations:
      # Manual checksum (auto-checksums handle envConfigmaps/envSecrets automatically)
      custom-hash: '{{ include "helpers.workload.checksum" (printf "%s" $.Values.envs) }}'

envs:
  RELEASE: '{{ .Release.Name }}'
```

### Escape Hatch

Deploy raw Kubernetes manifests for anything the chart doesn't natively support:

```yaml
extraDeploy:
  network-policy: |-
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: {{ include "helpers.app.fullname" (dict "name" "deny-all" "context" $) }}
      namespace: {{ .Release.Namespace | quote }}
    spec:
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress
```

---

## Real-World Scenarios

### Scenario 1 — API microservice with database

A typical REST API with external secrets, health checks, autoscaling, and a database migration hook:

```yaml
# ── API Deployment ──
deployments:
  api:
    image: registry.example.com/api
    imageTag: "2.1.0"
    replicas: 3
    ports:
      http: 8080
      metrics: 9090
    healthCheck:
      path: /healthz
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        memory: 512Mi
    envConfigmaps:
      - app-config
    envSecrets:
      - db-credentials

# ── Database migration (runs before each upgrade) ──
hooks:
  db-migrate:
    containers:
      - image: registry.example.com/api
        imageTag: "2.1.0"
        command: ["python", "manage.py", "migrate"]
    envSecrets:
      - db-credentials
    kind: pre-upgrade
    weight: "-5"

# ── Autoscaling ──
hpas:
  api:
    scaleTargetRef:
      name: api
    minReplicas: 3
    maxReplicas: 10
    targetCPU: 70

# ── Availability ──
pdbs:
  api:
    minAvailable: 1

# ── Config ──
configMaps:
  app-config:
    data:
      DATABASE_HOST: postgres.db.svc
      LOG_LEVEL: info

# ── Secrets from AWS ──
secretStores:
  aws:
    spec:
      provider:
        aws:
          service: SecretsManager
          region: eu-west-1

externalSecrets:
  db-credentials:
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws
        kind: SecretStore
      target:
        name: db-credentials
      data:
        - secretKey: DB_PASSWORD
          remoteRef:
            key: prod/api
            property: db_password
        - secretKey: DB_USERNAME
          remoteRef:
            key: prod/api
            property: db_username

# ── Monitoring ──
serviceMonitors:
  api:
    endpoints:
      - port: metrics
        path: /metrics
        interval: 30s
```

### Scenario 2 — Background workers + scheduled jobs

A worker Deployment (no incoming traffic) alongside scheduled batch jobs:

```yaml
defaults:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

# ── Worker (no ports, no Service) ──
deployments:
  worker:
    image: registry.example.com/worker
    imageTag: "1.3.0"
    replicas: 2
    service: false            # suppress auto-generated Service
    command: ["celery", "-A", "app", "worker", "--loglevel=info"]
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        memory: 1Gi

# ── Scheduled jobs ──
cronJobs:
  cleanup:
    schedule: "0 3 * * *"
    image: registry.example.com/worker
    imageTag: "1.3.0"
    command: ["python", "manage.py", "cleanup", "--older-than", "30d"]

  daily-report:
    schedule: "0 8 * * 1-5"
    image: registry.example.com/worker
    imageTag: "1.3.0"
    command: ["python", "manage.py", "send_report"]
    commandDurationAlert: 1800  # alert if > 30 min

  db-backup:
    schedule: "0 */6 * * *"
    singleOnly: true           # concurrencyPolicy: Forbid
    image: postgres
    imageTag: "16"
    command: ["pg_dump", "-h", "$DB_HOST", "mydb", "|", "gzip", ">", "/backup/dump.sql.gz"]
    volumes:
      - name: backup
        type: pvc
        claimName: backup-storage
    volumeMounts:
      - name: backup
        mountPath: /backup

# ── Shared env vars ──
envs:
  REDIS_URL: redis://redis:6379/0
  DATABASE_URL: postgres://db:5432/mydb
```

### Scenario 3 — Stateful application with persistent storage

A PostgreSQL StatefulSet with persistent volumes and a headless Service for stable DNS:

```yaml
statefulSets:
  postgres:
    image: postgres
    imageTag: "16"
    replicas: 1
    serviceName: postgres-headless
    ports:
      pg: 5432
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        memory: 2Gi
    containerSecurityContext:
      runAsUser: 999
      readOnlyRootFilesystem: false
    env:
      - name: PGDATA
        value: /var/lib/postgresql/data/pgdata
    envsFromSecret:
      POSTGRES_PASSWORD:
        name: pg-credentials
        key: password
    volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          storageClassName: gp3
          resources:
            requests:
              storage: 50Gi
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data

# Headless Service for stable pod DNS (postgres-0.postgres-headless.ns.svc)
services:
  postgres-headless:
    clusterIP: None
    ports:
      - name: pg
        port: 5432
```

### Scenario 4 — Multi-service release

Multiple microservices deployed together sharing common defaults:

```yaml
defaults:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  podAnnotations:
    sidecar.istio.io/inject: "true"
  preStopSleep: 5

deploymentsGeneral:
  replicas: 2

# All three Deployments inherit: 2 replicas, 100m/128Mi resources,
# Istio sidecar, 5s preStop sleep, hardened security contexts
deployments:
  frontend:
    image: registry.example.com/frontend
    imageTag: "3.0.0"
    ports:
      http: 3000
    healthCheck:
      path: /

  api:
    image: registry.example.com/api
    imageTag: "2.1.0"
    ports:
      http: 8080
      grpc: 9090
    healthCheck:
      path: /healthz
    replicas: 3              # override deploymentsGeneral

  worker:
    image: registry.example.com/worker
    imageTag: "2.1.0"
    service: false
    command: ["celery", "-A", "app", "worker"]
    resources:               # override defaults
      requests:
        cpu: 500m
        memory: 512Mi
```

---

## Cookbook

### Init containers

Init containers run before the main containers. They use the same container spec:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    initContainers:
      - name: wait-for-db
        image: busybox
        imageTag: "latest"
        command: ["sh", "-c", "until nc -z postgres 5432; do sleep 2; done"]
      - name: run-migrations
        image: my-api
        imageTag: "1.0.0"
        command: ["python", "manage.py", "migrate"]
```

Init containers inherit the workload's `containerSecurityContext` by default. Override per-container with `securityContext:`.

### Rolling update strategy

Control how Deployments roll out new versions:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxUnavailable: 0     # zero-downtime
        maxSurge: 1
    progressDeadlineSeconds: 300
```

For StatefulSets and DaemonSets, use `updateStrategy`:

```yaml
statefulSets:
  db:
    image: postgres
    imageTag: "16"
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        partition: 0        # update all pods

daemonSets:
  agent:
    image: agent
    imageTag: "1.0.0"
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        maxUnavailable: 1
```

### Topology spread constraints

Distribute pods across zones or nodes:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: my-release
            app.kubernetes.io/component: api
```

Or use the built-in node affinity preset for simpler zone targeting:

```yaml
nodeAffinityPreset:
  type: hard
  key: topology.kubernetes.io/zone
  values:
    - eu-west-1a
    - eu-west-1b
```

### Node selection and tolerations

Pin workloads to specific nodes or tolerate taints:

```yaml
# Global (all workloads)
defaults:
  nodeSelector:
    nodepool: application
  tolerations:
    - key: dedicated
      operator: Equal
      value: application
      effect: NoSchedule

# Per-workload override
deployments:
  gpu-worker:
    image: my-ml
    imageTag: "1.0.0"
    nodeSelector:
      nvidia.com/gpu: "true"
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

### Custom probes (beyond healthCheck)

The `healthCheck` shorthand generates HTTP GET probes. For TCP, gRPC, or exec probes, set them individually:

```yaml
deployments:
  redis-proxy:
    containers:
      - name: proxy
        image: redis
        imageTag: "7"
        ports:
          - name: redis
            containerPort: 6379
        startupProbe:
          tcpSocket:
            port: 6379
          periodSeconds: 5
        livenessProbe:
          exec:
            command: ["redis-cli", "ping"]
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 6379
          periodSeconds: 5
```

### DNS and host aliases

Override DNS resolution for pods:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    dnsPolicy: ClusterFirstWithHostNet
    hostAliases:
      - ip: "10.0.0.5"
        hostnames:
          - legacy-db.internal
          - old-db.internal
```

### Graceful shutdown with preStop + terminationGracePeriod

Combine `preStopSleep` with `terminationGracePeriodSeconds` for proper draining:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    terminationGracePeriodSeconds: 60

defaults:
  preStopSleep: 10   # sleep 10s before SIGTERM — lets LB drain connections
```

> **Tip**: Set `terminationGracePeriodSeconds` > `preStopSleep` so the app gets enough time to shut down after the sleep.

For custom lifecycle hooks (overrides `preStopSleep` for that container):

```yaml
deployments:
  api:
    containers:
      - name: app
        image: my-api
        imageTag: "1.0.0"
        lifecycle:
          preStop:
            httpGet:
              path: /shutdown
              port: 8080
          postStart:
            exec:
              command: ["sh", "-c", "echo started"]
```

### Downward API and per-pod env vars

Inject pod metadata as environment variables:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    env:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
      - name: NODE_NAME
        valueFrom:
          fieldRef:
            fieldPath: spec.nodeName
      - name: MEMORY_LIMIT
        valueFrom:
          resourceFieldRef:
            containerName: api
            resource: limits.memory
```

### Config hash for automatic rollouts

The chart **automatically injects** `checksum/configmap-<name>` and `checksum/secret-<name>` pod annotations for every chart-managed ConfigMap or Secret that a workload references via `envConfigmaps` / `envSecrets`. When the underlying data changes, the annotation hash changes, and Kubernetes triggers a rolling restart — no manual configuration needed.

```yaml
envs:
  LOG_LEVEL: info

deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    envConfigmaps:
      - envs          # ← auto-injects checksum/configmap-envs annotation
    envSecrets:
      - secret-envs   # ← auto-injects checksum/secret-secret-envs annotation
```

Auto-checksums are enabled by default. Disable globally, per-kind, or per-instance:

```yaml
# Global opt-out
defaults:
  autoChecksum: false

# Per-kind opt-out
deploymentsGeneral:
  autoChecksum: false

# Per-instance opt-out (overrides global and per-kind)
deployments:
  api:
    autoChecksum: false
```

For ConfigMaps or Secrets **not** managed by `envConfigmaps`/`envSecrets`, you can still use the manual helper:

```yaml
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"
    podAnnotations:
      config-hash: '{{ include "helpers.workload.checksum" (printf "%s%s" $.Values.envs $.Values.envsString) }}'
```

### Priority classes

Ensure critical workloads get scheduled first:

```yaml
defaults:
  priorityClassName: medium-priority

deployments:
  critical-api:
    image: my-api
    imageTag: "1.0.0"
    priorityClassName: high-priority   # override default
```

### ExternalName services

Route to services outside the cluster:

```yaml
services:
  legacy-api:
    type: ExternalName
    externalName: legacy.company.internal
    ports:
      - name: http
        port: 443
```

### Multiple environment sources per workload

Combine global envs, per-workload ConfigMaps, Secrets, and inline env in one workload:

```yaml
# Global (injected into ALL workloads)
envs:
  LOG_LEVEL: info
  REGION: eu-west-1

# Per-workload
deployments:
  api:
    image: my-api
    imageTag: "1.0.0"

    # Mount entire ConfigMaps/Secrets as envFrom
    envConfigmaps:
      - feature-flags
    envSecrets:
      - api-keys

    # Cherry-pick individual keys
    envsFromConfigmap:
      DATABASE_URL:
        name: db-config
        key: connection-string
    envsFromSecret:
      JWT_SECRET:
        name: auth-secrets
        key: jwt-key

    # Inline env entries (Kubernetes spec)
    env:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
```

Merge order: global `envs`/`secretEnvs` → general `envConfigmaps`/`envSecrets` → instance-level entries.

### CronJob-specific fields

CronJobs support additional fields beyond the basic workload config:

```yaml
cronJobs:
  etl:
    schedule: "0 * * * *"
    image: my-etl
    imageTag: "1.0.0"
    command: ["python", "etl.py"]
    singleOnly: true                   # concurrencyPolicy: Forbid
    suspend: false                     # pause scheduling without deleting
    startingDeadlineSeconds: 300       # max seconds late before skip
    activeDeadlineSeconds: 3600        # kill if running > 1 hour
    backoffLimit: 2                    # retry failed pods up to N times
    ttlSecondsAfterFinished: 86400    # clean up completed jobs after 24h
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 5
    restartPolicy: Never               # default: Never
    commandDurationAlert: 1800         # PrometheusRule if > 30 min
```

---

## Migrating from Standalone Charts

### From a per-service chart

If you currently maintain one Helm chart per microservice, migration is straightforward — move your container config into `deployments.<name>`:

**Before** (custom chart `templates/deployment.yaml`):
```yaml
# Your current values.yaml
image: registry.example.com/api
tag: "2.0.0"
replicaCount: 3
port: 8080
resources:
  requests:
    cpu: 250m
    memory: 256Mi
```

**After** (universal chart):
```yaml
deployments:
  api:
    image: registry.example.com/api
    imageTag: "2.0.0"
    replicas: 3
    ports:
      http: 8080
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
```

### From Bitnami / community charts

Community charts wrap a single application with extensive `values.yaml` options. The universal chart is a thin layer over raw Kubernetes specs, so most fields map directly:

| Bitnami pattern | Universal chart equivalent |
|---|---|
| `image.repository` + `image.tag` | `image` + `imageTag` |
| `replicaCount` | `replicas` |
| `service.type` + `service.port` | `ports: {http: 8080}` (auto-Service) or `services:` block |
| `ingress.enabled` + `ingress.hosts` | `httpRoutes:` or `istioVirtualServices:` |
| `resources.requests` | `resources.requests` (same) |
| `env` / `extraEnvVars` | `env:` / `envs:` / `envConfigmaps:` |
| `persistence.enabled` + `persistence.size` | `pvcs:` block with `mountPath` |
| `podSecurityContext` | `podSecurityContext` (same) |
| `serviceAccount.create` | `serviceAccounts:` block |

### Migration checklist

1. **Start minimal** — deploy just the workload first (`image` + `imageTag` + `ports`)
2. **Compare rendered output** — run `helm template` with both charts and diff
3. **Add features incrementally** — health checks, resources, env vars, volumes
4. **Move networking** — replace Ingress with HTTPRoute or VirtualService
5. **Consolidate** — merge per-service values files into one values file per environment

---

## Troubleshooting

### Common issues

**Pod stuck in CrashLoopBackOff:**
- Most likely cause: `readOnlyRootFilesystem: true` (the default). Your app may need to write to `/tmp` or a cache directory. Fix:
  ```yaml
  deployments:
    api:
      image: my-api
      imageTag: "1.0.0"
      volumes:
        - name: tmp
          type: emptyDir
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  ```
- Or disable it per-workload: `containerSecurityContext: {readOnlyRootFilesystem: false}`

**Service not created for my Deployment:**
- Auto-Service requires `ports:` in **map** form: `ports: {http: 8080}` ✓
- List form does NOT create a Service: `ports: [{containerPort: 8080}]` ✗
- Explicitly suppressed? Check for `service: false`

**Health check probes failing:**
- `healthCheck` only generates HTTP GET probes. If your app uses gRPC or TCP, use explicit `livenessProbe`/`readinessProbe` instead
- Default health check port is 8080. Override with `healthCheck.port`

**Volumes show `<no value>` or mount errors:**
- Typed volumes need the correct sub-field: `configMapName` for configMap, `secretName` for secret, `claimName` for pvc
- PVC auto-mounting only applies to Deployments, StatefulSets, and DaemonSets — not Jobs, CronJobs, or Hooks

**"Unable to run as non-root" errors:**
- Default `podSecurityContext` sets `runAsNonRoot: true`. Override for images that need root:
  ```yaml
  deployments:
    legacy:
      image: old-app
      imageTag: "1.0.0"
      podSecurityContext:
        runAsNonRoot: false
  ```

**Security context not applied to init/sidecar containers:**
- In single-container shorthand, set `containerSecurityContext` on the workload — it propagates to init containers and sidecars
- In multi-container form, set `securityContext` on each container individually, or use `containerSecurityContext` at the workload level for the shared default

**CronJob never runs:**
- Check `suspend: true` — set to `false` or remove it
- Verify the schedule string is quoted: `schedule: "0 3 * * *"`
- Check `startingDeadlineSeconds` — if the cluster was down during the scheduled time and no deadline is set, the job may be skipped

**Helm hook fails but deployment continues:**
- Hooks default to `kind: pre-install,pre-upgrade` with `weight: 5`. If a hook should block the release, ensure `deletePolicy` is `before-hook-creation` (default) and the Job's exit code is non-zero on failure

### Debugging tools

**Render templates locally** to inspect the output:
```bash
helm template my-release universal-chart/ -f my-values.yaml
```

**Render a single resource type** using grep:
```bash
helm template my-release universal-chart/ -f my-values.yaml | yq '. | select(.kind == "Deployment")'
```

**Diagnostic mode** — override all containers with `sleep infinity` to exec into a failing pod:
```yaml
diagnosticMode:
  enabled: true
```

**Validate against Kubernetes schemas:**
```bash
helm template my-release universal-chart/ -f my-values.yaml \
  | kubeconform -strict -ignore-missing-schemas
```

---

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
| defaults | object | `{"annotations":{},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"extraImagePullSecrets":[],"extraSelectorLabels":{},"extraVolumeMounts":[],"extraVolumes":[],"hookAnnotations":{},"labels":{},"podAnnotations":{},"podLabels":{},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"resources":{"limits":{"memory":"128Mi"},"requests":{"cpu":"100m","memory":"128Mi"}},"revisionHistoryLimit":3,"usePredefinedAffinity":true}` | Default settings applied to all workload templates (labels, annotations, pod metadata, volumes, etc.) |
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
| defaults.resources | object | `{"limits":{"memory":"128Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resource requests/limits applied to containers when not overridden. |
| defaults.revisionHistoryLimit | int | `3` | Default revisionHistoryLimit for Deployments and StatefulSets. Controls how many old ReplicaSets/ControllerRevisions are retained for rollback. Lower values reduce etcd/API-server load; set to 0 to disable rollback history entirely. |
| defaults.usePredefinedAffinity | bool | `true` | Use the chart's built-in pod affinity/anti-affinity rules. |
| deployments | object | `{}` | Kubernetes Deployment resources. Each key becomes the resource name. Single-container shorthand: set `image:` at workload level instead of a `containers:` list. `ports:` (map form `{name: port}`) auto-creates containerPorts AND a matching ClusterIP Service. `resources:` raw requests/limits map. `healthCheck:` sets liveness, readiness, and startup probes. Override service behaviour with `service: false` (suppress) or `service:` fields such as `type`, `clusterIP`, `externalTrafficPolicy`, `loadBalancerSourceRanges`, `loadBalancerIP`, `sessionAffinity`, `sessionAffinityConfig`, `healthCheckNodePort`, `publishNotReadyAddresses`, `ipFamilies`, and `ipFamilyPolicy`. The full `containers:` list still works for multi-container workloads. |
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
| imagePullSecrets | list | `[]` | Image pull secret names referenced in every pod spec. Secrets must be pre-created in the namespace. |
| imageUpdaters | object | `{}` | Argo CD Image Updater resources. Each key becomes the resource name. Configures automatic image updates for Argo CD applications. |
| issuers | object | `{}` | cert-manager Issuer resources (namespace-scoped). Each key becomes the resource name. |
| istioAuthorizationPolicies | object | `{}` | Istio AuthorizationPolicy resources. Each key becomes the resource name. |
| istioDestinationRules | object | `{}` | Istio DestinationRule resources. Each key becomes the resource name. |
| istioGateways | object | `{}` | Istio Gateway resources. Each key becomes the resource name. |
| istioPeerAuthentications | object | `{}` | Istio PeerAuthentication resources (mTLS policy). Each key becomes the resource name. |
| istioVirtualServices | object | `{}` | Istio VirtualService resources. Each key becomes the resource name. |
| jobs | object | `{}` | Kubernetes Job resources (non-hook). Each key becomes the resource name. |
| jobsGeneral | object | `{"usePredefinedAffinity":false}` | Shared defaults for all Jobs. |
| nodeAffinityPreset | object | `{"key":"","type":"","values":[]}` | Node affinity preset configuration. |
| nodeAffinityPreset.key | string | `""` | Node label key to match (e.g. `kubernetes.io/e2e-az-name`). |
| nodeAffinityPreset.type | string | `""` | Affinity type. Allowed values: `soft`, `hard`, or empty string to disable. |
| nodeAffinityPreset.values | list | `[]` | Node label values to match. |
| pdbs | object | `{}` | Kubernetes PodDisruptionBudget resources. Each key becomes the resource name. |
| persistentVolumes | object | `{}` | Kubernetes PersistentVolume resources (cluster-scoped, no namespace). Each key becomes the resource name. Thin passthrough — `spec:` goes directly to the Kubernetes resource unchanged. |
| podAffinityPreset | string | `"soft"` | Pod affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| podAntiAffinityPreset | string | `"soft"` | Pod anti-affinity preset. Allowed values: `soft`, `hard`, or empty string to disable. |
| pvcs | object | `{}` | Kubernetes PersistentVolumeClaim resources. Each key becomes the resource name. PVCs are automatically added to the `volumes` block in each workload (excluding hooks). Set `mountPath` on a PVC to also auto-mount it into every container. Set `workloads` to limit auto-mounting to specific workload names. Set `keepOnDelete` to retain the PVC on uninstall. |
| releasePrefix | string | `""` | Prefix prepended to all resource names. Leave empty to disable. |
| secretEnvs | object | `{}` | Secret environment variables injected via Secret envFrom. |
| secretEnvsString | string | `""` | Secret environment variables as a raw YAML string. |
| secretStores | object | `{}` | External Secrets Operator SecretStore resources (namespace-scoped). Each key becomes the resource name. |
| secrets | object | `{}` | Kubernetes Secret resources. Each key becomes the resource name. |
| serviceAccounts | object | `{}` | Kubernetes ServiceAccount resources. Each key becomes the resource name. |
| serviceAccountsGeneral | object | `{}` | Shared defaults for all ServiceAccounts. |
| serviceMonitors | object | `{}` | Prometheus ServiceMonitor resources. Each key becomes the resource name. |
| services | object | `{}` | Kubernetes Service resources. Each key becomes the resource name. If `workload` is omitted, the selector defaults to the service key name. Set `selector` to override the selector verbatim. ExternalName services omit selectors. |
| statefulSets | object | `{}` | Kubernetes StatefulSet resources. Each key becomes the resource name. Uses `updateStrategy` instead of `strategy`. Adds `volumeClaimTemplates` support. |
| statefulSetsGeneral | object | `{}` | Shared defaults for all StatefulSets. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Origo SoftwareSolutions DevOps |  |  |

## Development

### Prerequisites

Install these tools before working on the chart locally:

**Required:**

| Tool | Version | Purpose | Install |
|---|---|---|---|
| [Helm](https://helm.sh/) | 3.19+ | Chart rendering, linting, packaging | [Install docs](https://helm.sh/docs/intro/install/) |
| [helm-unittest](https://github.com/helm-unittest/helm-unittest) | 1.0+ | Unit test runner (Helm plugin) | `helm plugin install https://github.com/helm-unittest/helm-unittest --version 1.0.3` |
| [Python](https://www.python.org/) | 3.9+ | Required by pre-commit and helmfmt | [Download](https://www.python.org/downloads/) (often pre-installed on macOS/Linux) |
| [pre-commit](https://pre-commit.com/) | 3.0+ | Git hook manager — auto-runs formatting and docs generation on every commit | [Install docs](https://pre-commit.com/#installation) |

> **Note:** You do not need to install [helmfmt](https://github.com/digitalstudium/helmfmt) or [helm-docs](https://github.com/norwoodj/helm-docs) separately — pre-commit downloads and manages them automatically when the hooks run.

**Optional (CI runs these, but useful locally):**

| Tool | Purpose | Install |
|---|---|---|
| [kubeconform](https://github.com/yannh/kubeconform) | Schema validation of rendered manifests | [Releases](https://github.com/yannh/kubeconform/releases) |
| [chart-testing (ct)](https://github.com/helm/chart-testing) | Chart linting with git diff awareness | [Releases](https://github.com/helm/chart-testing/releases) |

### First-time setup

```bash
# Clone and enter the repo
git clone https://github.com/OrigoSoftwareSolutions/universal-chart.git
cd universal-chart

# Install the helm-unittest plugin (one-time)
helm plugin install https://github.com/helm-unittest/helm-unittest --version 1.0.3

# Install pre-commit hooks (one-time) — runs helmfmt + helm-docs automatically on git commit
pre-commit install
```

### Day-to-day commands

```bash
# Lint (must pass before pushing)
helm lint universal-chart/ --strict

# Run unit tests (must pass before pushing)
helm unittest universal-chart/ --strict --file 'tests/*.yaml'

# Run a single test suite
helm unittest universal-chart/ --strict --file 'tests/deployment_test.yaml'

# Render templates (smoke test)
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml

# Render with Istio CRD resolution
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  --api-versions networking.istio.io/v1beta1

# Regenerate README (required after values.yaml changes — also runs automatically via pre-commit)
helm-docs --chart-search-root universal-chart/ -o ../README.md

# Format templates (also runs automatically via pre-commit)
helmfmt universal-chart/

# Schema validation (optional — CI runs this)
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.33.6 \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

### Pre-commit hooks

The repo uses [pre-commit](https://pre-commit.com/) hooks (configured in `.pre-commit-config.yaml`) that run automatically on each `git commit`:

| Hook | What it does |
|---|---|
| **helmfmt** | Auto-formats all `.yaml`/`.yml`/`.tpl` files in `universal-chart/` (2-space indent, consistent whitespace) |
| **helm-docs** | Regenerates `README.md` from the gotmpl template + `values.yaml` comments |

If a hook modifies files, the commit is aborted so you can review and re-stage. Just run `git add . && git commit` again.

### Style & formatting rules

Enforced by `.yamllint` and `.helmfmt`:

- **Indent**: 2 spaces — no tabs
- **Line length**: max 150 characters
- **Booleans**: `true`/`false` only (never `yes`/`no`/`on`/`off`)
- **No trailing spaces**; max 3 consecutive empty lines
- **`nindent`** value must match actual rendered indentation level
- Quote image tags that look numeric: `imageTag: "1.25"`

## Contributing & Release

### Making changes

1. Create a branch from `main`
2. Make your changes in `universal-chart/`
3. Run locally before pushing:
   ```bash
   helm lint universal-chart/ --strict
   helm unittest universal-chart/ --strict --file 'tests/*.yaml'
   ```
4. If you changed `values.yaml`, regenerate docs:
   ```bash
   helm-docs --chart-search-root universal-chart/ -o ../README.md
   ```
5. Open a PR against `main`

### CI checks (automated on every PR)

Five parallel jobs run on every pull request:

| Job | What it does |
|---|---|
| `lint` | `helm lint --strict` + kubeconform schema validation |
| `unittest` | All helm-unittest suites |
| `security` | Trivy scan on rendered manifests |
| `ct-lint` | chart-testing `ct lint` |
| `docs-check` | Verifies `README.md` matches `helm-docs` output |

All five must pass before merge.

### Versioning & release

This chart follows [SemVer](https://semver.org/):

- **Patch** (`1.3.0` → `1.3.1`): Bug fixes, doc updates, test additions
- **Minor** (`1.3.0` → `1.4.0`): New features, new resource types, new values keys
- **Major** (`1.3.0` → `2.0.0`): Breaking changes — renamed/removed values keys, changed default behavior

**To release a new version:**

1. Bump `version:` in `universal-chart/Chart.yaml`
2. Merge to `main`
3. GitHub Actions automatically packages and pushes to `oci://ghcr.io/origosoftwaresolutions/universal-chart`

No manual tagging required. The `Chart.yaml` version is the single source of truth.

### Adding a new resource type

1. Create the template in `universal-chart/templates/` (`.yaml` extension only)
2. Add a plural values key in `values.yaml` (e.g. `myResources: {}`) with a `# --` helm-docs comment
3. Add schema validation in `values.schema.json` if the resource has structured fields
4. Write a test suite in `universal-chart/tests/<resource>_test.yaml`
5. Regenerate docs: `helm-docs --chart-search-root universal-chart/ -o ../README.md`
6. Run all checks: `helm lint --strict && helm unittest --strict --file 'tests/*.yaml'`

## Source Code

* <https://github.com/OrigoSoftwareSolutions/universal-chart>

## License

Maintained by [Origo Software Solutions](https://github.com/OrigoSoftwareSolutions).

---

## Acknowledgements

This chart grew out of [nixys/universal-chart](https://github.com/nixys/universal-chart), an open-source Helm chart by Nixys Ltd. Thank you for the foundation.
