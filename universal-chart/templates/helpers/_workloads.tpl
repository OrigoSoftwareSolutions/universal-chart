{{- define "helpers.workloads.envs" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $v := .value -}}
  {{- if or (or (or $v.envsFromConfigmap $v.envsFromSecret) $v.env) (or (or $general.envsFromConfigmap $general.envsFromSecret) $general.env)}}
env:
    {{ with $general.envsFromConfigmap }}{{- include "helpers.configmaps.includeEnv" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.envsFromConfigmap }}{{- include "helpers.configmaps.includeEnv" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $general.envsFromSecret }}{{- include "helpers.secrets.includeEnv" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.envsFromSecret }}{{- include "helpers.secrets.includeEnv" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $general.env }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.env }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}{{- end }}
  {{- end }}
{{- end }}

{{- define "helpers.workloads.envsFrom" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $v := .value -}}
  {{- if or (or (or $v.envConfigmaps $v.envSecrets) $v.envFrom) (or (or $general.envConfigmaps $general.envSecrets) $general.envFrom)}}
envFrom:
    {{ with $general.envConfigmaps }}{{- include "helpers.configmaps.includeEnvConfigmap" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.envConfigmaps }}{{- include "helpers.configmaps.includeEnvConfigmap" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $general.envSecrets }}{{- include "helpers.secrets.includeEnvSecret" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.envSecrets }}{{- include "helpers.secrets.includeEnvSecret" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $general.envFrom }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}{{- end }}
    {{ with $v.envFrom }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}{{- end }}
  {{- end }}
{{- end }}

{{- define "helpers.workload.checksum" -}}
{{ . | toString | sha256sum }}
{{- end -}}

{{- /* Converts a ports map {name: port} to a containerPorts list */}}
{{- define "helpers.workload.singleContainerPorts" -}}
  {{- $ports := . -}}
  {{- range $portName := keys $ports | sortAlpha }}
    {{- $portNum := index $ports $portName }}
- name: {{ $portName }}
  containerPort: {{ $portNum | int }}
  protocol: TCP
  {{- end }}
{{- end }}

{{- /* Resolves resource presets (nano/small/medium/large/xlarge) or passes raw resources through */}}
{{- define "helpers.workload.resolveResources" -}}
  {{- if typeIs "string" . -}}
    {{- $presets := dict
    "nano"   (dict "requests" (dict "cpu" "50m"   "memory" "64Mi")  "limits" (dict "memory" "64Mi"))
    "small"  (dict "requests" (dict "cpu" "100m"  "memory" "128Mi") "limits" (dict "memory" "128Mi"))
    "medium" (dict "requests" (dict "cpu" "250m"  "memory" "512Mi") "limits" (dict "memory" "512Mi"))
    "large"  (dict "requests" (dict "cpu" "500m"  "memory" "1Gi")   "limits" (dict "memory" "1Gi"))
    "xlarge" (dict "requests" (dict "cpu" "1000m" "memory" "2Gi")   "limits" (dict "memory" "2Gi")) -}}
    {{- if hasKey $presets . -}}
    {{- get $presets . | toYaml -}}
    {{- else -}}
      {{- fail (printf "resources: unknown preset %q. Valid presets: nano, small, medium, large, xlarge" .) -}}
    {{- end -}}
  {{- else -}}
  {{- . | toYaml -}}
  {{- end -}}
{{- end }}

{{- /* Generates an HTTP probe from a healthCheck shorthand {path, port, ...} */}}
{{- define "helpers.workload.healthCheckProbe" -}}
httpGet:
  path: {{ .path | default "/healthz" }}
  port: {{ .port | default 8080 }}
initialDelaySeconds: {{ .initialDelaySeconds | default 0 }}
periodSeconds: {{ .periodSeconds | default 10 }}
timeoutSeconds: {{ .timeoutSeconds | default 1 }}
failureThreshold: {{ .failureThreshold | default 3 }}
{{- end }}
