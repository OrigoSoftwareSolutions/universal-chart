{{- define "helpers.pod" -}}
{{- $ := .context -}}
  {{- $componentLabel := dict "app.kubernetes.io/component" (.name | trunc 63 | trimSuffix "-") -}}
  {{- $extraLabels := mustMergeOverwrite $componentLabel (default dict .extraLabels) -}}
  {{- $name := .name | trunc 63 | trimSuffix "-" -}}
  {{- with .value -}}
    {{- $usePredefinedAffinity := .usePredefinedAffinity | default $.Values.defaults.usePredefinedAffinity -}}
    {{- $podSecurityContext := .podSecurityContext | default .securityContext -}}
    {{- $workloadHealthCheck := .healthCheck | default $.Values.defaults.healthCheck -}}
    {{- if (ne .serviceAccountName nil) }}
serviceAccountName: {{ .serviceAccountName }}
    {{- else if (ne $.Values.defaults.serviceAccountName nil) }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.serviceAccountName "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .hostAliases nil) }}
      {{- with .hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.hostAliases nil) }}
      {{- with $.Values.defaults.hostAliases }}
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
    {{- else if (ne $.Values.defaults.priorityClassName nil) }}
      {{- with $.Values.defaults.priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- if (ne .dnsPolicy nil) }}
      {{- with .dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.dnsPolicy nil) }}
      {{- with $.Values.defaults.dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- with .dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- else with $.Values.defaults.dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- end }}
    {{- if (ne .nodeSelector nil) }}
      {{- with .nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.nodeSelector nil) }}
      {{- with $.Values.defaults.nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne .tolerations nil) }}
      {{- with .tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.tolerations nil) }}
      {{- with $.Values.defaults.tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne .topologySpreadConstraints nil) }}
      {{- with .topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.topologySpreadConstraints nil) }}
      {{- with $.Values.defaults.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- /* Deep-merge pod securityContext: defaults (with deprecated `securityContext` alias) → workload. Each tier overrides previous keys; unset keys retain prior tier's defaults. Setting an empty dict at any tier clears the cascade below it (escape hatch). */ -}}
    {{- $effectivePodSecCtx := dict -}}
    {{- $defaultsPSC := $.Values.defaults.podSecurityContext -}}
    {{- if (eq $defaultsPSC nil) }}{{ $defaultsPSC = $.Values.defaults.securityContext }}{{ end -}}
    {{- with $defaultsPSC }}{{ $effectivePodSecCtx = mustMergeOverwrite $effectivePodSecCtx (deepCopy .) }}{{ end -}}
    {{- if (and (kindIs "map" $podSecurityContext) (eq (len $podSecurityContext) 0)) }}{{ $effectivePodSecCtx = dict }}
    {{- else if $podSecurityContext }}{{ $effectivePodSecCtx = mustMergeOverwrite $effectivePodSecCtx (deepCopy $podSecurityContext) }}{{ end -}}
      {{- if $effectivePodSecCtx }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" $effectivePodSecCtx "context" $) | nindent 2 }}
      {{- end }}
      {{- $pullSecrets := concat ($.Values.imagePullSecrets | default list) ($.Values.defaults.extraImagePullSecrets | default list) (.imagePullSecrets | default list) (.extraImagePullSecrets | default list) | uniq -}}
      {{- if $pullSecrets }}
imagePullSecrets:
        {{- range $pullSecrets }}
- name: {{ . }}
        {{- end }}
      {{- end }}
      {{- $termGrace := .terminationGracePeriodSeconds | default $.Values.defaults.terminationGracePeriodSeconds -}}
      {{- if (ne $termGrace nil) }}
terminationGracePeriodSeconds: {{ $termGrace }}
      {{- end }}
      {{- if (ne .hostNetwork nil) }}
hostNetwork: {{ .hostNetwork }}
      {{- else if (ne $.Values.defaults.hostNetwork nil) }}
hostNetwork: {{ $.Values.defaults.hostNetwork }}
      {{- end }}
      {{- if (ne .hostPID nil) }}
hostPID: {{ .hostPID }}
      {{- else if (ne $.Values.defaults.hostPID nil) }}
hostPID: {{ $.Values.defaults.hostPID }}
      {{- end }}
      {{- if (ne .hostIPC nil) }}
hostIPC: {{ .hostIPC }}
      {{- else if (ne $.Values.defaults.hostIPC nil) }}
hostIPC: {{ $.Values.defaults.hostIPC }}
      {{- end }}
      {{- if (ne .shareProcessNamespace nil) }}
shareProcessNamespace: {{ .shareProcessNamespace }}
      {{- else if (ne $.Values.defaults.shareProcessNamespace nil) }}
shareProcessNamespace: {{ $.Values.defaults.shareProcessNamespace }}
      {{- end }}
      {{- if (ne .automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ .automountServiceAccountToken }}
      {{- else if (ne $.Values.defaults.automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ $.Values.defaults.automountServiceAccountToken }}
      {{- end }}
      {{- if (ne .runtimeClassName nil) }}
runtimeClassName: {{ .runtimeClassName }}
      {{- else if (ne $.Values.defaults.runtimeClassName nil) }}
runtimeClassName: {{ $.Values.defaults.runtimeClassName }}
      {{- end }}
      {{- if (ne .overhead nil) }}
overhead: {{- include "helpers.tplvalues.render" (dict "value" .overhead "context" $) | nindent 2 }}
      {{- else if (ne $.Values.defaults.overhead nil) }}
overhead: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.overhead "context" $) | nindent 2 }}
      {{- end }}
      {{- if (ne .readinessGates nil) }}
readinessGates: {{- include "helpers.tplvalues.render" (dict "value" .readinessGates "context" $) | nindent 2 }}
      {{- else if (ne $.Values.defaults.readinessGates nil) }}
readinessGates: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.readinessGates "context" $) | nindent 2 }}
      {{- end }}
      {{- if (ne .schedulingGates nil) }}
schedulingGates: {{- include "helpers.tplvalues.render" (dict "value" .schedulingGates "context" $) | nindent 2 }}
      {{- else if (ne $.Values.defaults.schedulingGates nil) }}
schedulingGates: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.schedulingGates "context" $) | nindent 2 }}
      {{- end }}
      {{- if (ne .os nil) }}
os: {{- include "helpers.tplvalues.render" (dict "value" .os "context" $) | nindent 2 }}
      {{- else if (ne $.Values.defaults.os nil) }}
os: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.os "context" $) | nindent 2 }}
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
