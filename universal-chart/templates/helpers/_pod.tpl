{{- define "helpers.pod" -}}
{{- $ := .context -}}
  {{- $general := .general -}}
  {{- $extraLabels := .extraLabels -}}
  {{- $usePredefinedAffinity := $.Values.defaults.usePredefinedAffinity -}}
  {{- if (ne $general.usePredefinedAffinity nil) }}{{ $usePredefinedAffinity = $general.usePredefinedAffinity }}{{ end -}}
  {{- $name := .name -}}
  {{- with .value -}}
    {{- if .serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" .serviceAccountName "context" $) | nindent 2 }}
    {{- else if $.Values.defaults.serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.serviceAccountName  "context" $) | nindent 2 }}
    {{- end }}
    {{- if .hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" .hostAliases "context" $) | nindent 2 }}
    {{- else if $.Values.defaults.hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.hostAliases "context" $) | nindent 2 }}
    {{- end }}
    {{- if .affinity }}
affinity: {{- include "helpers.tplvalues.render" ( dict "value" .affinity "context" $) | nindent 2 }}
    {{- else if $general.affinity }}
affinity: {{- include "helpers.tplvalues.render" ( dict "value" $general.affinity "context" $) | nindent 2 }}
    {{- else if $usePredefinedAffinity }}
affinity:
      {{- if $.Values.nodeAffinityPreset.type }}
  nodeAffinity: {{- include "helpers.affinities.nodes" (dict "type" $.Values.nodeAffinityPreset.type "key" $.Values.nodeAffinityPreset.key "values" $.Values.nodeAffinityPreset.values "context" $) | nindent 4 }}
      {{- end }}
  podAffinity: {{- include "helpers.affinities.pods" (dict "type" $.Values.podAffinityPreset "extraLabels" $extraLabels "context" $) | nindent 4 }}
  podAntiAffinity: {{- include "helpers.affinities.pods" (dict "type" $.Values.podAntiAffinityPreset "extraLabels" $extraLabels "context" $) | nindent 4 }}
    {{- end }}
    {{- if .priorityClassName }}
priorityClassName: {{ .priorityClassName }}
    {{- else if $.Values.defaults.priorityClassName }}
priorityClassName: {{ $.Values.defaults.priorityClassName }}
    {{- end }}
    {{- if .dnsPolicy }}
dnsPolicy: {{ .dnsPolicy }}
    {{- else if $.Values.defaults.dnsPolicy }}
dnsPolicy: {{ $.Values.defaults.dnsPolicy }}
    {{- end }}
    {{- with .nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
    {{- end }}

    {{- $combined := .tolerations | default ( $.Values.defaults.tolerations | default list ) }}
    {{- if $combined }}
tolerations:
      {{- include "helpers.tplvalues.render" (dict "value" $combined "context" $) | nindent 2 }}
    {{- end }}

    {{- with .securityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
    {{- end }}
    {{- if or $.Values.imagePullSecrets $.Values.defaults.extraImagePullSecrets .extraImagePullSecrets .imagePullSecrets }}
imagePullSecrets:
      {{- range $sName, $v := $.Values.imagePullSecrets }}
- name: {{ $sName }}
      {{- end }}
      {{- with .imagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
      {{- with .extraImagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
      {{- with $.Values.defaults.extraImagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
    {{- end }}
    {{- if .terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ .terminationGracePeriodSeconds }}
    {{- end }}
    {{- with .initContainers}}
initContainers:
      {{- range . }}
        {{- with .name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
        {{- else }}
- name: {{ printf "%s-init-%s" $name (lower (randAlphaNum 5)) }}
        {{- end }}
        {{- $image := $.Values.defaultImage }}{{ with .image }}{{ $image = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
        {{- $imageTag := $.Values.defaultImageTag }}{{ with .imageTag }}{{ $imageTag = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
  image: {{ $image }}:{{ $imageTag }}
  imagePullPolicy: {{ .imagePullPolicy | default $.Values.defaultImagePullPolicy }}
        {{- with .securityContext }}
  securityContext: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
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
        {{- $initEnvs := include "helpers.workloads.envs" (dict "value" . "general" $general "context" $) | trim -}}
        {{- if $initEnvs }}{{ $initEnvs | nindent 2 }}{{- end }}
        {{- $initEnvsFrom := include "helpers.workloads.envsFrom" (dict "value" . "general" $general "context" $) | trim -}}
        {{- if $initEnvsFrom }}{{ $initEnvsFrom | nindent 2 }}{{- end }}
        {{- with .ports }}
  ports: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
        {{- end }}
        {{- with .lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- with .startupProbe }}
  startupProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- with .livenessProbe }}
  livenessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- with .readinessProbe }}
  readinessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- with .resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- $vmounts := include "helpers.volumes.renderVolumeMounts" (dict "value" . "general" $general "context" $) }}
  volumeMounts:{{- if eq (trim $vmounts) "[]" }} []{{- else }}{{ $vmounts | nindent 2 }}{{- end }}
      {{- end }}{{- end }}
      {{- if and (not .containers) .image }}
containers:
- name: {{ $name }}
  image: {{ .image }}
  imagePullPolicy: {{ .imagePullPolicy | default $.Values.defaultImagePullPolicy }}
        {{- with .securityContext }}
  securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- if $.Values.diagnosticMode.enabled }}
  args: {{- include "helpers.tplvalues.render" (dict "value" $.Values.diagnosticMode.args "context" $) | nindent 4 }}
        {{- else if .args }}
  args: {{- include "helpers.tplvalues.render" (dict "value" .args "context" $) | nindent 4 }}
        {{- end }}
        {{- if $.Values.diagnosticMode.enabled }}
  command: {{- include "helpers.tplvalues.render" (dict "value" $.Values.diagnosticMode.command "context" $) | nindent 4 }}
        {{- else if .command }}
          {{- if typeIs "string" .command }}
  command: {{ printf "[\"%s\"]" (join ("\", \"") (without (splitList " " .command) "" )) }}
          {{- else }}
  command: {{- include "helpers.tplvalues.render" (dict "value" .command "context" $) | nindent 4 }}
          {{- end }}
        {{- end }}
        {{- $scEnvs := include "helpers.workloads.envs" (dict "value" . "general" $general "context" $) | trim -}}
        {{- if $scEnvs }}{{ $scEnvs | nindent 2 }}{{- end }}
        {{- $scEnvsFrom := include "helpers.workloads.envsFrom" (dict "value" . "general" $general "context" $) | trim -}}
        {{- if $scEnvsFrom }}{{ $scEnvsFrom | nindent 2 }}{{- end }}
        {{- if kindIs "map" .ports }}
  ports: {{- include "helpers.workload.singleContainerPorts" .ports | trim | nindent 2 }}
        {{- end }}
        {{- with .lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
        {{- end }}
        {{- if .healthCheck }}
  startupProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
  livenessProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
  readinessProbe: {{- include "helpers.workload.healthCheckProbe" .healthCheck | nindent 4 }}
        {{- else }}
          {{- with .startupProbe }}
  startupProbe: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .livenessProbe }}
  livenessProbe: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .readinessProbe }}
  readinessProbe: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
          {{- end }}
        {{- end }}
        {{- if .resources }}
  resources: {{- include "helpers.tplvalues.render" (dict "value" .resources "context" $) | nindent 4 }}
        {{- end }}
        {{- $scVmounts := include "helpers.volumes.renderVolumeMounts" (dict "value" . "general" $general "context" $) }}
  volumeMounts:{{- if eq (trim $scVmounts) "[]" }} []{{- else }}{{ $scVmounts | nindent 2 }}{{- end }}
      {{- else }}
containers:
        {{- range .containers }}
          {{- with .name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
          {{- else }}
- name: {{ printf "%s-%s" $name (lower (randAlphaNum 5)) }}
          {{- end }}
          {{- $image := $.Values.defaultImage }}{{ with .image }}{{ $image = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
          {{- $imageTag := $.Values.defaultImageTag }}{{ with .imageTag }}{{ $imageTag = include "helpers.tplvalues.render" ( dict "value" . "context" $) }}{{ end }}
  image: {{ $image }}:{{ $imageTag }}
  imagePullPolicy: {{ .imagePullPolicy | default $.Values.defaultImagePullPolicy }}
          {{- with .securityContext }}
  securityContext: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
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
          {{- with .ports }}
  ports: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
          {{- end }}
          {{- with .lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .startupProbe }}
  startupProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .livenessProbe }}
  livenessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .readinessProbe }}
  readinessProbe: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- with .resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 4 }}
          {{- end }}
          {{- $vmounts := include "helpers.volumes.renderVolumeMounts" (dict "value" . "general" $general "context" $) }}
  volumeMounts:{{- if eq (trim $vmounts) "[]" }} []{{- else }}{{ $vmounts | nindent 2 }}{{- end }}
        {{- end }}
      {{- end }}
      {{- $vols := include "helpers.volumes.renderVolume" (dict "value" . "general" $general "context" $) }}
volumes:{{- if eq (trim $vols) "[]" }} []{{- else }}{{ $vols }}{{- end }}
    {{- end -}}
  {{- end -}}
