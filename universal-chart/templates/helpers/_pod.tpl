{{- define "helpers.pod" -}}
{{- $ := .context -}}
  {{- $componentLabel := dict "app.kubernetes.io/component" (.name | trunc 63 | trimSuffix "-") -}}
  {{- $extraLabels := mustMergeOverwrite $componentLabel (default dict .extraLabels) -}}
  {{- $name := .name | trunc 63 | trimSuffix "-" -}}
  {{- with .value -}}
    {{- $usePredefinedAffinity := .usePredefinedAffinity | default $.Values.usePredefinedAffinity -}}
    {{- $podSecurityContext := .podSecurityContext | default .securityContext -}}
    {{- $workloadHealthCheck := .healthCheck -}}
    {{- if (ne .serviceAccountName nil) }}
serviceAccountName: {{ .serviceAccountName }}
    {{- end }}
    {{- if (ne .hostAliases nil) }}
      {{- with .hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- if (ne .affinity nil) }}
      {{- with .affinity }}
affinity: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $usePredefinedAffinity }}
affinity:
      {{- $nodeAffStr := "" -}}
      {{- if $.Values.nodeAffinityPreset.type -}}
        {{- $nodeAffStr = include "helpers.affinities.nodes" (dict "type" $.Values.nodeAffinityPreset.type "key" $.Values.nodeAffinityPreset.key "values" $.Values.nodeAffinityPreset.values "context" $) | trim -}}
      {{- end -}}
      {{- if $nodeAffStr }}
  nodeAffinity: {{- $nodeAffStr | nindent 4 }}
      {{- end }}
      {{- $podAffStr := include "helpers.affinities.pods" (dict "type" $.Values.podAffinityPreset "extraLabels" $extraLabels "context" $) | trim -}}
      {{- if $podAffStr }}
  podAffinity: {{- $podAffStr | nindent 4 }}
      {{- end }}
      {{- $podAntiAffStr := include "helpers.affinities.pods" (dict "type" $.Values.podAntiAffinityPreset "extraLabels" $extraLabels "context" $) | trim -}}
      {{- if $podAntiAffStr }}
  podAntiAffinity: {{- $podAntiAffStr | nindent 4 }}
      {{- end }}
    {{- end }}
    {{- if (ne .priorityClassName nil) }}
      {{- with .priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- if (ne .dnsPolicy nil) }}
      {{- with .dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- with .dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- end }}
    {{- if (ne .nodeSelector nil) }}
      {{- with .nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne .tolerations nil) }}
      {{- with .tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne .topologySpreadConstraints nil) }}
      {{- with .topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if $podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" $podSecurityContext "context" $) | nindent 2 }}
    {{- end }}
    {{- $pullSecrets := concat ($.Values.imagePullSecrets | default list) (.imagePullSecrets | default list) (.extraImagePullSecrets | default list) | uniq -}}
    {{- if $pullSecrets }}
imagePullSecrets:
      {{- range $pullSecrets }}
- name: {{ . }}
      {{- end }}
    {{- end }}
    {{- if (ne .terminationGracePeriodSeconds nil) }}
terminationGracePeriodSeconds: {{ .terminationGracePeriodSeconds }}
    {{- end }}
    {{- if (ne .hostNetwork nil) }}
hostNetwork: {{ .hostNetwork }}
    {{- end }}
    {{- if (ne .hostPID nil) }}
hostPID: {{ .hostPID }}
    {{- end }}
    {{- if (ne .hostIPC nil) }}
hostIPC: {{ .hostIPC }}
    {{- end }}
    {{- if (ne .shareProcessNamespace nil) }}
shareProcessNamespace: {{ .shareProcessNamespace }}
    {{- end }}
    {{- if (ne .automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ .automountServiceAccountToken }}
    {{- end }}
    {{- if (ne .runtimeClassName nil) }}
runtimeClassName: {{ .runtimeClassName }}
    {{- end }}
    {{- if (ne .overhead nil) }}
overhead: {{- include "helpers.tplvalues.render" (dict "value" .overhead "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .readinessGates nil) }}
readinessGates: {{- include "helpers.tplvalues.render" (dict "value" .readinessGates "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .schedulingGates nil) }}
schedulingGates: {{- include "helpers.tplvalues.render" (dict "value" .schedulingGates "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .os nil) }}
os: {{- include "helpers.tplvalues.render" (dict "value" .os "context" $) | nindent 2 }}
    {{- end }}
    {{- $workloadContainerSecCtx := .containerSecurityContext -}}
    {{- with .initContainers}}
initContainers:
      {{- range $idx, $ic := . }}
        {{- with $ic.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
        {{- else }}
- name: {{ printf "%s-init-%d" ($name | trunc 52 | trimSuffix "-") $idx }}
        {{- end }}
        {{- include "helpers.container.render" (dict "value" $ic "name" "" "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" false "workloadContainerSecurityContext" $workloadContainerSecCtx "workloadHealthCheck" $workloadHealthCheck "isInitContainer" true) | indent 0 }}
      {{- end }}{{- end }}
      {{- if not .containers }}
containers:
- name: {{ $name }}
        {{- include "helpers.container.render" (dict "value" . "name" $name "workloadName" $name "context" $ "enableHealthCheckShorthand" true "enableMapPorts" true "useDefaultImage" true "workloadContainerSecurityContext" .containerSecurityContext "workloadHealthCheck" $workloadHealthCheck) | indent 0 }}
      {{- else }}
containers:
        {{- range $idx, $ct := .containers }}
          {{- with $ct.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
          {{- else }}
- name: {{ printf "%s-%d" ($name | trunc 58 | trimSuffix "-") $idx }}
          {{- end }}
          {{- include "helpers.container.render" (dict "value" $ct "name" "" "workloadName" $name "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" false "workloadContainerSecurityContext" $workloadContainerSecCtx "workloadHealthCheck" $workloadHealthCheck) | indent 0 }}
        {{- end }}
      {{- end }}
      {{- $vols := include "helpers.volumes.renderVolume" (dict "value" . "context" $) }}
volumes:{{- if eq (trim $vols) "[]" }} []{{- else }}
{{ regexReplaceAll "\n{2,}" ($vols | trim) "\n" }}{{- end }}
    {{- end -}}
  {{- end -}}
