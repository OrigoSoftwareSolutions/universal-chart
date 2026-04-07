{{- define "helpers.pod" -}}
{{- $ := .context -}}
  {{- $general := .general -}}
  {{- $componentLabel := dict "app.kubernetes.io/component" (.name | trunc 63 | trimSuffix "-") -}}
  {{- $extraLabels := mustMergeOverwrite $componentLabel (default dict .extraLabels) -}}
  {{- $usePredefinedAffinity := $.Values.defaults.usePredefinedAffinity -}}
  {{- if (ne $general.usePredefinedAffinity nil) }}{{ $usePredefinedAffinity = $general.usePredefinedAffinity }}{{ end -}}
  {{- $name := .name | trunc 63 | trimSuffix "-" -}}
  {{- $autoPvcs := .autoPvcs | default false -}}
  {{- with .value -}}
    {{- if (ne .usePredefinedAffinity nil) }}{{ $usePredefinedAffinity = .usePredefinedAffinity }}{{ end -}}
    {{- $podSecurityContext := .securityContext -}}
    {{- if (ne .podSecurityContext nil) }}{{ $podSecurityContext = .podSecurityContext }}{{ end -}}
    {{- $generalPodSecurityContext := $general.securityContext -}}
    {{- if (ne $general.podSecurityContext nil) }}{{ $generalPodSecurityContext = $general.podSecurityContext }}{{ end -}}
    {{- if (ne .serviceAccountName nil) }}
      {{- with .serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.serviceAccountName nil) }}
      {{- with $general.serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.serviceAccountName "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .hostAliases nil) }}
      {{- with .hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.hostAliases nil) }}
      {{- with $general.hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.hostAliases "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .affinity nil) }}
      {{- with .affinity }}
affinity: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.affinity nil) }}
      {{- with $general.affinity }}
affinity: {{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $usePredefinedAffinity }}
affinity:
      {{- if $.Values.nodeAffinityPreset.type }}
  nodeAffinity: {{- include "helpers.affinities.nodes" (dict "type" $.Values.nodeAffinityPreset.type "key" $.Values.nodeAffinityPreset.key "values" $.Values.nodeAffinityPreset.values "context" $) | nindent 4 }}
      {{- end }}
  podAffinity: {{- include "helpers.affinities.pods" (dict "type" $.Values.podAffinityPreset "extraLabels" $extraLabels "context" $) | nindent 4 }}
  podAntiAffinity: {{- include "helpers.affinities.pods" (dict "type" $.Values.podAntiAffinityPreset "extraLabels" $extraLabels "context" $) | nindent 4 }}
    {{- end }}
    {{- if (ne .priorityClassName nil) }}
      {{- with .priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.priorityClassName nil) }}
      {{- with $general.priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.priorityClassName "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .dnsPolicy nil) }}
      {{- with .dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.dnsPolicy nil) }}
      {{- with $general.dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.dnsPolicy "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .nodeSelector nil) }}
      {{- with .nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.nodeSelector nil) }}
      {{- with $general.nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.nodeSelector "context" $) | nindent 2 }}
    {{- end }}

    {{- if (ne .tolerations nil) }}
      {{- with .tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.tolerations nil) }}
      {{- with $general.tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.tolerations }}
tolerations:
      {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.tolerations "context" $) | nindent 2 }}
    {{- end }}

    {{- if (ne .topologySpreadConstraints nil) }}
      {{- with .topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.topologySpreadConstraints nil) }}
      {{- with $general.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.topologySpreadConstraints "context" $) | nindent 2 }}
    {{- end }}

    {{- if (ne $podSecurityContext nil) }}
      {{- with $podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $generalPodSecurityContext nil) }}
      {{- with $generalPodSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if $.Values.defaults.podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.podSecurityContext "context" $) | nindent 2 }}
    {{- end }}
    {{- if or $.Values.imagePullSecrets $.Values.defaults.extraImagePullSecrets .extraImagePullSecrets .imagePullSecrets }}
imagePullSecrets:
      {{- range $.Values.imagePullSecrets }}
- name: {{ . }}
      {{- end }}
      {{- range $.Values.defaults.extraImagePullSecrets }}
- name: {{ . }}
      {{- end }}
      {{- range .imagePullSecrets }}
- name: {{ . }}
      {{- end }}
      {{- range .extraImagePullSecrets }}
- name: {{ . }}
      {{- end }}
    {{- end }}
    {{- $termGrace := 0 -}}
    {{- $termGraceSet := false -}}
    {{- if (ne .terminationGracePeriodSeconds nil) }}{{ $termGrace = .terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if and (not $termGraceSet) (ne $general.terminationGracePeriodSeconds nil) }}{{ $termGrace = $general.terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if and (not $termGraceSet) (ne $.Values.defaults.terminationGracePeriodSeconds nil) }}{{ $termGrace = $.Values.defaults.terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if $termGraceSet }}
terminationGracePeriodSeconds: {{ $termGrace }}
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
        {{- include "helpers.container.render" (dict "value" $ic "name" "" "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" true "workloadContainerSecurityContext" $workloadContainerSecCtx) | indent 0 }}
      {{- end }}{{- end }}
      {{- if and (not .containers) .image }}
containers:
- name: {{ $name }}
        {{- include "helpers.container.render" (dict "value" . "name" $name "general" $general "context" $ "enableHealthCheckShorthand" true "enableMapPorts" true "useDefaultImage" false "autoPvcs" $autoPvcs "workloadContainerSecurityContext" .containerSecurityContext) | indent 0 }}
      {{- else }}
containers:
        {{- range $idx, $ct := .containers }}
          {{- with $ct.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
          {{- else }}
- name: {{ printf "%s-%d" ($name | trunc 58 | trimSuffix "-") $idx }}
          {{- end }}
          {{- include "helpers.container.render" (dict "value" $ct "name" "" "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" true "autoPvcs" $autoPvcs "workloadContainerSecurityContext" $workloadContainerSecCtx) | indent 0 }}
        {{- end }}
      {{- end }}
      {{- $vols := include "helpers.volumes.renderVolume" (dict "value" . "general" $general "context" $ "autoPvcs" $autoPvcs) }}
volumes:{{- if eq (trim $vols) "[]" }} []{{- else }}
{{ regexReplaceAll "\n{2,}" ($vols | trim) "\n" }}{{- end }}
    {{- end -}}
  {{- end -}}
