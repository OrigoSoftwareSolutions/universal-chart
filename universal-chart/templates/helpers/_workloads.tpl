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
context — the root context ($)

Controlled by:
defaults.autoChecksum  (bool, default true)  — global opt-out
<instance>.autoChecksum (bool)                — per-workload override
*/}}
{{- define "helpers.workload.autoChecksums" -}}
  {{- $ctx := .context -}}
  {{- $v := .value -}}

  {{- /* Two-level merge for the autoChecksum flag: instance > defaults (true) */}}
  {{- $enabled := true -}}
  {{- if hasKey $ctx.Values.defaults "autoChecksum" -}}
    {{- $enabled = $ctx.Values.defaults.autoChecksum -}}
  {{- end -}}
  {{- if hasKey $v "autoChecksum" -}}
    {{- $enabled = $v.autoChecksum -}}
  {{- end -}}

  {{- if $enabled -}}
    {{- /* Collect references the workload makes via envConfigmaps/envSecrets
    (whole-resource envFrom) and envsFromConfigmap/envsFromSecret
    (cherry-pick valueFrom). All hold rendered Kubernetes resource names
    (verbatim). */}}
    {{- $cmRefs := list -}}
    {{- with $v.envConfigmaps -}}
      {{- range . }}{{ $cmRefs = append $cmRefs . }}{{ end -}}
    {{- end -}}
    {{- with $v.envsFromConfigmap -}}
      {{- range $envVar, $ref := . }}{{- if kindIs "map" $ref }}{{- with $ref.name }}{{ $cmRefs = append $cmRefs . }}{{ end }}{{ end }}{{ end -}}
    {{- end -}}
    {{- $secRefs := list -}}
    {{- with $v.envSecrets -}}
      {{- range . }}{{ $secRefs = append $secRefs . }}{{ end -}}
    {{- end -}}
    {{- with $v.envsFromSecret -}}
      {{- range $envVar, $ref := . }}{{- if kindIs "map" $ref }}{{- with $ref.name }}{{ $secRefs = append $secRefs . }}{{ end }}{{ end }}{{ end -}}
    {{- end -}}

    {{- /* Chart-managed ConfigMaps referenced explicitly. Match by rendered
    K8s name: the user writes the actual name in envConfigmaps, so we
    compare against helpers.app.fullname of each chart-managed CM. */}}
    {{- range $cmName, $cm := $ctx.Values.configMaps -}}
      {{- $rendered := include "helpers.app.fullname" (dict "name" $cmName "context" $ctx) -}}
      {{- if and (has $rendered $cmRefs) $cm.data }}
checksum/configmap-{{ $cmName }}: {{ $cm.data | toJson | sha256sum }}
      {{- end -}}
    {{- end -}}
    {{- range $secName, $sec := $ctx.Values.secrets -}}
      {{- $rendered := include "helpers.app.fullname" (dict "name" $secName "context" $ctx) -}}
      {{- if and (has $rendered $secRefs) $sec.data }}
checksum/secret-{{ $secName }}: {{ $sec.data | toJson | sha256sum }}
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
