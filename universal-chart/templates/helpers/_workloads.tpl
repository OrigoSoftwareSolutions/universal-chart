{{- define "helpers.workloads.envs" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $v := .value -}}
  {{- if or (or (or $v.envsFromConfigmap $v.envsFromSecret) $v.env) (or (or $general.envsFromConfigmap $general.envsFromSecret) $general.env)}}
env:
    {{- with $general.envsFromConfigmap }}
      {{ include "helpers.configmaps.includeEnv" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $v.envsFromConfigmap }}
      {{ include "helpers.configmaps.includeEnv" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $general.envsFromSecret }}
      {{ include "helpers.secrets.includeEnv" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $v.envsFromSecret }}
      {{ include "helpers.secrets.includeEnv" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $general.env }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $v.env }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "helpers.workloads.envsFrom" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $v := .value -}}
  {{- $cmRefs := list -}}
  {{- with $general.envConfigmaps -}}
    {{- range . }}{{ $cmRefs = append $cmRefs . }}{{ end -}}
  {{- end -}}
  {{- with $v.envConfigmaps -}}
    {{- range . }}{{ $cmRefs = append $cmRefs . }}{{ end -}}
  {{- end -}}
  {{- $secRefs := list -}}
  {{- with $general.envSecrets -}}
    {{- range . }}{{ $secRefs = append $secRefs . }}{{ end -}}
  {{- end -}}
  {{- with $v.envSecrets -}}
    {{- range . }}{{ $secRefs = append $secRefs . }}{{ end -}}
  {{- end -}}
  {{- $hasGlobalEnvs := or (not (empty $ctx.Values.envs)) (not (empty $ctx.Values.envsString)) -}}
  {{- if and $hasGlobalEnvs (not (has "envs" $cmRefs)) -}}
    {{- $cmRefs = prepend $cmRefs "envs" -}}
  {{- end -}}
  {{- $hasGlobalSecretEnvs := or (not (empty $ctx.Values.secretEnvs)) (not (empty $ctx.Values.secretEnvsString)) -}}
  {{- if and $hasGlobalSecretEnvs (not (has "secret-envs" $secRefs)) -}}
    {{- $secRefs = prepend $secRefs "secret-envs" -}}
  {{- end -}}
  {{- if or $cmRefs (or $secRefs (or $general.envFrom $v.envFrom)) }}
envFrom:
    {{- with $cmRefs }}
      {{ include "helpers.configmaps.includeEnvConfigmap" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $secRefs }}
      {{ include "helpers.secrets.includeEnvSecret" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $general.envFrom }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end -}}
    {{- with $v.envFrom }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "helpers.workload.checksum" -}}
{{ . | toString | sha256sum }}
{{- end -}}


{{- /*
helpers.workload.autoChecksums — Automatically generates checksum/... pod
annotations for every chart-managed ConfigMap and Secret that the workload
references via envConfigmaps / envSecrets.  When the underlying data changes
the annotation hash changes, triggering a rolling restart.

Expects a dict:
value   — the workload instance (e.g. $d inside range)
general — the *General block (e.g. $general)
context — the root context ($)

Controlled by:
defaults.autoChecksum  (bool, default true)  — global opt-out
<instance>.autoChecksum (bool)                — per-workload override
<general>.autoChecksum  (bool)                — per-kind override
*/}}
{{- define "helpers.workload.autoChecksums" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $v := .value -}}

  {{- /* Three-level merge for the autoChecksum flag: instance > general > defaults (true) */}}
  {{- $enabled := true -}}
  {{- if hasKey $ctx.Values.defaults "autoChecksum" -}}
    {{- $enabled = $ctx.Values.defaults.autoChecksum -}}
  {{- end -}}
  {{- if hasKey $general "autoChecksum" -}}
    {{- $enabled = $general.autoChecksum -}}
  {{- end -}}
  {{- if hasKey $v "autoChecksum" -}}
    {{- $enabled = $v.autoChecksum -}}
  {{- end -}}

  {{- if $enabled -}}
    {{- /* Collect envConfigmaps references (general + instance) */}}
    {{- $cmRefs := list -}}
    {{- with $general.envConfigmaps -}}
      {{- range . }}{{ $cmRefs = append $cmRefs . }}{{ end -}}
    {{- end -}}
    {{- with $v.envConfigmaps -}}
      {{- range . }}{{ $cmRefs = append $cmRefs . }}{{ end -}}
    {{- end -}}

    {{- /* Collect envSecrets references (general + instance) */}}
    {{- $secRefs := list -}}
    {{- with $general.envSecrets -}}
      {{- range . }}{{ $secRefs = append $secRefs . }}{{ end -}}
    {{- end -}}
    {{- with $v.envSecrets -}}
      {{- range . }}{{ $secRefs = append $secRefs . }}{{ end -}}
    {{- end -}}

    {{- if and (or (not (empty $ctx.Values.envs)) (not (empty $ctx.Values.envsString))) (not (has "envs" $cmRefs)) -}}
      {{- $cmRefs = prepend $cmRefs "envs" -}}
    {{- end -}}
    {{- if and (or (not (empty $ctx.Values.secretEnvs)) (not (empty $ctx.Values.secretEnvsString))) (not (has "secret-envs" $secRefs)) -}}
      {{- $secRefs = prepend $secRefs "secret-envs" -}}
    {{- end -}}

    {{- /* Hash referenced ConfigMaps */}}
    {{- range $cmRefs -}}
      {{- $refName := . -}}
      {{- if eq $refName "envs" -}}
        {{- /* Global envs ConfigMap — hash envs + envsString */}}
        {{- if or (not (empty $ctx.Values.envs)) (not (empty $ctx.Values.envsString)) }}
checksum/configmap-envs: {{ printf "%v%v" $ctx.Values.envs $ctx.Values.envsString | sha256sum }}
        {{- end -}}
      {{- else -}}
        {{- /* Named configMap — look up in $.Values.configMaps */}}
        {{- $cm := index $ctx.Values.configMaps $refName | default dict -}}
        {{- with $cm.data }}
checksum/configmap-{{ $refName }}: {{ . | toJson | sha256sum }}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- /* Hash referenced Secrets */}}
    {{- range $secRefs -}}
      {{- $refName := . -}}
      {{- if eq $refName "secret-envs" -}}
        {{- /* Global secretEnvs Secret — hash secretEnvs + secretEnvsString */}}
        {{- if or (not (empty $ctx.Values.secretEnvs)) (not (empty $ctx.Values.secretEnvsString)) }}
checksum/secret-secret-envs: {{ printf "%v%v" $ctx.Values.secretEnvs $ctx.Values.secretEnvsString | sha256sum }}
        {{- end -}}
      {{- else -}}
        {{- /* Named secret — look up in $.Values.secrets */}}
        {{- $sec := index $ctx.Values.secrets $refName | default dict -}}
        {{- with $sec.data }}
checksum/secret-{{ $refName }}: {{ . | toJson | sha256sum }}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* Converts a ports map {name: port} or {name: {port: N, protocol: P}} to a containerPorts list */}}
{{- define "helpers.workload.singleContainerPorts" -}}
  {{- $ports := . -}}
  {{- range $portName := keys $ports | sortAlpha }}
    {{- $portVal := index $ports $portName }}
    {{- if kindIs "map" $portVal }}
- name: {{ $portName }}
  containerPort: {{ $portVal.port | int }}
  protocol: {{ $portVal.protocol | default "TCP" }}
    {{- else }}
- name: {{ $portName }}
  containerPort: {{ $portVal | int }}
  protocol: TCP
    {{- end }}
  {{- end }}
{{- end }}


{{- /* Generates an HTTP probe from a healthCheck shorthand {path, port, ...} */}}
{{- /* probeType: "startup" | "liveness" | "readiness" — controls initialDelaySeconds default */}}
{{- define "helpers.workload.healthCheckProbe" -}}
  {{- $probeType := .probeType | default "startup" -}}
  {{- $defaultDelay := 0 -}}
  {{- if eq $probeType "liveness" }}{{ $defaultDelay = 15 }}{{ end -}}
  {{- if eq $probeType "readiness" }}{{ $defaultDelay = 5 }}{{ end -}}
httpGet:
  path: {{ .healthCheck.path | default "/healthz" }}
  port: {{ .healthCheck.port | default 8080 }}
  {{- with .healthCheck.scheme }}
  scheme: {{ . }}
  {{- end }}
initialDelaySeconds: {{ .healthCheck.initialDelaySeconds | default $defaultDelay }}
periodSeconds: {{ .healthCheck.periodSeconds | default 10 }}
timeoutSeconds: {{ .healthCheck.timeoutSeconds | default 1 }}
{{- if ne $probeType "startup" }}
  {{- with .healthCheck.successThreshold }}
successThreshold: {{ . }}
  {{- end }}
{{- end }}
failureThreshold: {{ .healthCheck.failureThreshold | default 3 }}
{{- end }}
