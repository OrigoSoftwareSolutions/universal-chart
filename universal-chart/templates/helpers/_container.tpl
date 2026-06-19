{{- define "helpers.container.render" -}}
  {{- $ := .context -}}
  {{- $general := .general -}}
  {{- $name := .name -}}
  {{- $c := .value -}}
  {{- $enableHealthCheck := .enableHealthCheckShorthand -}}
  {{- $enableMapPorts := .enableMapPorts -}}
  {{- $useDefaultImage := .useDefaultImage -}}
  {{- $workloadName := .workloadName | default .name -}}
  {{- $workloadContainerSecurityContext := .workloadContainerSecurityContext -}}
  {{- $workloadHealthCheck := .workloadHealthCheck -}}
  {{- $isInitContainer := .isInitContainer | default false -}}
  {{- with $c -}}
    {{- if $useDefaultImage }}
      {{- $image := include "helpers.tplvalues.render" (dict "value" (required (printf "deployments.%s (or matching workload kind): .image is required. Root-level defaultImage/defaultImageTag fallbacks were removed in chart 1.7.3 — set deployments.%s.image (and deployments.%s.imageTag) explicitly so AIU writes are unambiguous." $name $name $name) .image) "context" $) -}}
      {{- $hasEmbeddedTag := regexMatch "^([^/]+/)*[^/:]+:[^/]+$" $image -}}
      {{- if and (not .imageTag) $hasEmbeddedTag }}
  image: {{ $image }}
      {{- else if .imageTag }}
  image: {{ $image }}:{{ include "helpers.tplvalues.render" (dict "value" .imageTag "context" $) }}
      {{- else }}
  image: {{ $image }}
      {{- end }}
    {{- else }}
      {{- $image := include "helpers.tplvalues.render" (dict "value" (required "Explicit containers[] and initContainers[] entries must set image" .image) "context" $) -}}
      {{- $hasEmbeddedTag := regexMatch "^([^/]+/)*[^/:]+:[^/]+$" $image -}}
      {{- if and (not .imageTag) $hasEmbeddedTag }}
  image: {{ $image }}
      {{- else if .imageTag }}
  image: {{ $image }}:{{ include "helpers.tplvalues.render" (dict "value" .imageTag "context" $) }}
      {{- else }}
  image: {{ $image }}
      {{- end }}
    {{- end }}
  imagePullPolicy: {{ include "helpers.tplvalues.render" (dict "value" (.imagePullPolicy | default $.Values.defaultImagePullPolicy) "context" $) }}
    {{- /* Deep-merge container securityContext: defaults → general → workload → container. Each tier overrides previous keys; unset keys retain prior tier's secure defaults so adding a single capability does not strip allowPrivilegeEscalation: false / readOnlyRootFilesystem: true / capabilities.drop. */ -}}
    {{- $effectiveContainerSecCtx := dict -}}
    {{- with $.Values.defaults.containerSecurityContext }}{{ $effectiveContainerSecCtx = mustMergeOverwrite $effectiveContainerSecCtx (deepCopy .) }}{{ end -}}
    {{- with $general.containerSecurityContext }}{{ $effectiveContainerSecCtx = mustMergeOverwrite $effectiveContainerSecCtx (deepCopy .) }}{{ end -}}
    {{- with $workloadContainerSecurityContext }}{{ $effectiveContainerSecCtx = mustMergeOverwrite $effectiveContainerSecCtx (deepCopy .) }}{{ end -}}
    {{- with .securityContext }}{{ $effectiveContainerSecCtx = mustMergeOverwrite $effectiveContainerSecCtx (deepCopy .) }}{{ end -}}
    {{- if $effectiveContainerSecCtx }}
  securityContext: {{- include "helpers.tplvalues.render" (dict "value" $effectiveContainerSecCtx "context" $) | nindent 4 }}
    {{- end }}
    {{- if and $.Values.diagnosticMode.enabled (not $isInitContainer) }}
  args: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.diagnosticMode.args "context" $) | nindent 2 }}
    {{- else if .args }}
  args: {{- include "helpers.tplvalues.render" ( dict "value" .args "context" $) | nindent 2 }}
    {{- end }}
    {{- if and $.Values.diagnosticMode.enabled (not $isInitContainer) }}
  command: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.diagnosticMode.command "context" $) | nindent 2 }}
    {{- else if .command }}
  command: {{- include "helpers.tplvalues.render" ( dict "value" .command "context" $) | nindent 2 }}
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
    {{- if .lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" ( dict "value" .lifecycle "context" $) | nindent 4 }}
    {{- else if not $isInitContainer }}
      {{- if $general.lifecycle }}
  lifecycle: {{- include "helpers.tplvalues.render" ( dict "value" $general.lifecycle "context" $) | nindent 4 }}
      {{- else }}
        {{- $preStopSleep := $c.preStopSleep | default $general.preStopSleep | default $.Values.defaults.preStopSleep -}}
        {{- if $preStopSleep }}
  lifecycle:
    preStop:
      exec:
        command: ["sh", "-c", "sleep {{ $preStopSleep }}"]
        {{- end }}
      {{- end }}
    {{- end }}
    {{- if not $.Values.diagnosticMode.enabled }}
      {{- $effectiveHealthCheck := "" -}}
      {{- if and $enableHealthCheck .healthCheck }}{{ $effectiveHealthCheck = .healthCheck }}{{ end -}}
      {{- $hasOwnProbe := or .startupProbe .livenessProbe .readinessProbe -}}
      {{- if and (not $effectiveHealthCheck) (not $hasOwnProbe) (not $isInitContainer) $workloadHealthCheck }}{{ $effectiveHealthCheck = $workloadHealthCheck }}{{ end -}}
      {{- if $effectiveHealthCheck }}
  startupProbe: {{- include "helpers.workload.healthCheckProbe" (dict "probeType" "startup" "healthCheck" $effectiveHealthCheck) | nindent 4 }}
  livenessProbe: {{- include "helpers.workload.healthCheckProbe" (dict "probeType" "liveness" "healthCheck" $effectiveHealthCheck) | nindent 4 }}
  readinessProbe: {{- include "helpers.workload.healthCheckProbe" (dict "probeType" "readiness" "healthCheck" $effectiveHealthCheck) | nindent 4 }}
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
    {{- end }}
    {{- if .resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" .resources "context" $) | nindent 4 }}
    {{- else if $general.resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" $general.resources "context" $) | nindent 4 }}
    {{- else if $.Values.defaults.resources }}
  resources: {{- include "helpers.tplvalues.render" ( dict "value" $.Values.defaults.resources "context" $) | nindent 4 }}
    {{- end }}
    {{- $vmounts := include "helpers.volumes.renderVolumeMounts" (dict "value" . "general" $general "context" $ "name" $workloadName) }}
  volumeMounts:{{- if eq (trim $vmounts) "[]" }} []{{- else }}{{ $vmounts | trim | nindent 2 }}{{- end }}
  {{- end -}}
{{- end -}}
