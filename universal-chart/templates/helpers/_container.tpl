{{- define "helpers.container.render" -}}
  {{- $ := .context -}}
  {{- $general := .general -}}
  {{- $name := .name -}}
  {{- $c := .value -}}
  {{- $enableHealthCheck := .enableHealthCheckShorthand -}}
  {{- $enableMapPorts := .enableMapPorts -}}
  {{- $useDefaultImage := .useDefaultImage -}}
  {{- with $c -}}
    {{- if $useDefaultImage }}
      {{- $image := $.Values.defaultImage }}{{ with .image }}{{ $image = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
      {{- $imageTag := $.Values.defaultImageTag }}{{ with .imageTag }}{{ $imageTag = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
  image: {{ $image }}:{{ $imageTag }}
    {{- else }}
  image: {{ .image }}
    {{- end }}
  imagePullPolicy: {{ .imagePullPolicy | default $.Values.defaultImagePullPolicy }}
    {{- if .securityContext }}
  securityContext: {{- include "helpers.tplvalues.render" ( dict "value" .securityContext "context" $) | nindent 4 }}
    {{- else if $.Values.defaults.containerSecurityContext }}
  securityContext: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.defaults.containerSecurityContext "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.diagnosticMode.enabled }}
  args: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.diagnosticMode.args "context" $) | nindent 2 }}
    {{- else if .args }}
  args: {{- include "helpers.tplvalues.render" ( dict "value" .args "context" $) | nindent 2 }}
    {{- end }}
    {{- if $.Values.diagnosticMode.enabled }}
  command: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.diagnosticMode.command "context" $) | nindent 2 }}
    {{- else if .command }}
      {{- if typeIs "string" .command }}
  command: {{ printf "[\"%s\"]" (join ("\", \"") (without (splitList " " .command) "" )) }}
      {{- else }}
  command: {{- include "helpers.tplvalues.render" ( dict "value" .command "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- $envs := include "helpers.workloads.envs" (dict "value" . "general" $general "context" $) | trim -}}
    {{- if $envs }}{{ $envs | nindent 2 }}{{- end }}
    {{- $envsFrom := include "helpers.workloads.envsFrom" (dict "value" . "general" $general "context" $) | trim -}}
    {{- if $envsFrom }}{{ $envsFrom | nindent 2 }}{{- end }}
    {{- if and $enableMapPorts (kindIs "map" .ports) }}
  ports: {{- include "helpers.workload.singleContainerPorts" .ports | trim | nindent 2 }}
    {{- else }}
      {{- with .ports }}
  ports: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- with .lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
    {{- end }}
    {{- if and $enableHealthCheck .healthCheck }}
  startupProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
  livenessProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
  readinessProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
    {{- else }}
      {{- with .startupProbe }}
  startupProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
      {{- end }}
      {{- with .livenessProbe }}
  livenessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
      {{- end }}
      {{- with .readinessProbe }}
  readinessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
      {{- end }}
    {{- end }}
    {{- if .resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" .resources "context" $) | nindent 4 }}
    {{- else if $.Values.defaults.resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.defaults.resources "context" $) | nindent 4 }}
    {{- end }}
    {{- $vmounts := include "helpers.volumes.renderVolumeMounts" (dict "value" . "general" $general "context" $) }}
  volumeMounts:{{- if eq (trim $vmounts) "[]" }} []{{- else }}{{ $vmounts | nindent 2 }}{{- end }}
  {{- end -}}
{{- end -}}
