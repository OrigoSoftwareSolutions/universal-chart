# Origo Universal Helm Chart

![Version: 1.2.1](https://img.shields.io/badge/Version-1.2.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

One Helm chart for everything. Instead of maintaining a separate chart per service, define all your Kubernetes resources — Deployments, CronJobs, Services, ExternalSecrets, Istio configs, and more — in a single values file.

## Supported Resources

| Core Workloads | Networking | Storage & Config | CRDs |
|---|---|---|---|
| Deployment | Service | ConfigMap | ExternalSecret / ClusterExternalSecret |
| StatefulSet | HTTPRoute (Gateway API) | Secret | SecretStore / ClusterSecretStore |
| DaemonSet | Istio VirtualService | PersistentVolumeClaim | Certificate / Issuer / ClusterIssuer |
| CronJob / Job | Istio Gateway | ServiceAccount | Istio PeerAuthentication |
| Helm Hooks | Istio DestinationRule | | Istio AuthorizationPolicy |
| HPA / PDB | ServiceMonitor | | ImageUpdater (Argo CD) |

## Install

```bash
helm install my-release oci://ghcr.io/origosoftwaresolutions/universal-chart \
  --version 1.2.1 \
  -f my-values.yaml
```

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
    command: "python manage.py cleanup --older-than 30d"

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
    command: "node server.js"  # string is auto-split into array
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

Same shorthand as Deployments. Adds `volumeClaimTemplates` and uses `updateStrategy` instead of `strategy`:

```yaml
statefulSets:
  postgres:
    image: postgres
    imageTag: "16"
    replicas: 1
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
    command: "python generate_report.py"
    resources:
      requests:
        cpu: 100m
        memory: 256Mi

  db-backup:
    schedule: "0 */6 * * *"
    singleOnly: true          # shorthand for concurrencyPolicy: Forbid
    image: postgres
    imageTag: "16"
    command: "pg_dump -h $DB_HOST mydb | gzip > /backup/dump.sql.gz"
    commandDurationAlert: 3600  # PrometheusRule fires if job runs > 1 hour
```

### Jobs

```yaml
jobs:
  seed-data:
    image: registry.example.com/my-api
    imageTag: "1.0.0"
    command: "python manage.py seed"
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
    hookAnnotations:
      helm.sh/hook: pre-upgrade
      helm.sh/hook-weight: "-5"
      helm.sh/hook-delete-policy: before-hook-creation
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
istiovirtualservices:
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
istiogateways:
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

### Istio DestinationRule

```yaml
istiodestinationrules:
  api:
    host: api.default.svc.cluster.local
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
        http:
          h2UpgradePolicy: DEFAULT
```

### Istio PeerAuthentication

```yaml
istioPeerAuthentications:
  strict-mtls:
    spec:
      mtls:
        mode: STRICT
```

### Istio AuthorizationPolicy

```yaml
istioAuthorizationPolicies:
  allow-frontend:
    spec:
      action: ALLOW
      rules:
        - from:
            - source:
                principals:
                  - "cluster.local/ns/frontend/sa/frontend"
```

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
    extraSelectorLabels:      # additional labels for pod selection
      app: api
```

---

## Identity & Access

### ServiceAccount with auto-RBAC

Define `role:` or `clusterRole:` inside a ServiceAccount to auto-create Role/ClusterRole and their bindings:

```yaml
serviceAccount:
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
    command: "python etl.py"
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

Available `*General` blocks: `deploymentsGeneral`, `statefulSetsGeneral`, `daemonSetsGeneral`, `cronJobsGeneral`, `jobsGeneral`, `hooksGeneral`, `serviceAccountGeneral`.

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

Override per-workload:

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
      config-hash: '{{ include "helpers.workload.checksum" (printf "%s" $.Values.envs) }}'

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
| imageUpdaters | object | `{}` | Argo CD Image Updater resources. Each key becomes the resource name. Configures automatic image updates for Argo CD applications. |
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
| pvcs | object | `{}` | Kubernetes PersistentVolumeClaim resources. Each key becomes the resource name. PVCs are automatically added to the `volumes` block in each workload (excluding hooks). Set `mountPath` on a PVC to also auto-mount it into every container. |
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
