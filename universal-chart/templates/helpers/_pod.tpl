{{- define "helpers.pod" -}}
{{- $ := .context -}}
  {{- $general := .general -}}
  {{- $extraLabels := .extraLabels -}}
  {{- $usePredefinedAffinity := $.Values.defaults.usePredefinedAffinity -}}
  {{- if (ne $general.usePredefinedAffinity nil) }}{{ $usePredefinedAffinity = $general.usePredefinedAffinity }}{{ end -}}
  {{- $name := .name -}}
  {{- $autoPvcs := .autoPvcs | default false -}}
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

    {{- if .topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" .topologySpreadConstraints "context" $) | nindent 2 }}
    {{- else if $general.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" $general.topologySpreadConstraints "context" $) | nindent 2 }}
    {{- else if $.Values.defaults.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.topologySpreadConstraints "context" $) | nindent 2 }}
    {{- end }}

    {{- if .securityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" .securityContext "context" $) | nindent 2 }}
    {{- else if $general.securityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" $general.securityContext "context" $) | nindent 2 }}
    {{- else if $.Values.defaults.podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" $.Values.defaults.podSecurityContext "context" $) | nindent 2 }}
    {{- end }}
    {{- if or $.Values.imagePullSecrets $.Values.defaults.extraImagePullSecrets .extraImagePullSecrets .imagePullSecrets }}
imagePullSecrets:
      {{- range $.Values.imagePullSecrets }}
- name: {{ . }}
      {{- end }}
      {{- with .imagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
      {{- with .extraImagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
      {{- with $.Values.defaults.extraImagePullSecrets }}{{- include "helpers.tplvalues.render" ( dict "value" . "context" $) | nindent 0 }}{{- end }}
    {{- end }}
    {{- $termGrace := 0 -}}
    {{- $termGraceSet := false -}}
    {{- if .terminationGracePeriodSeconds }}{{ $termGrace = .terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if and (not $termGraceSet) $general.terminationGracePeriodSeconds }}{{ $termGrace = $general.terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if and (not $termGraceSet) $.Values.defaults.terminationGracePeriodSeconds }}{{ $termGrace = $.Values.defaults.terminationGracePeriodSeconds }}{{ $termGraceSet = true }}{{ end -}}
    {{- if $termGraceSet }}
terminationGracePeriodSeconds: {{ $termGrace }}
    {{- end }}
    {{- with .initContainers}}
initContainers:
      {{- range $idx, $ic := . }}
        {{- with $ic.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
        {{- else }}
- name: {{ printf "%s-init-%d" $name $idx }}
        {{- end }}
        {{- include "helpers.container.render" (dict "value" $ic "name" "" "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" true) | indent 0 }}
      {{- end }}{{- end }}
      {{- if and (not .containers) .image }}
containers:
- name: {{ $name }}
        {{- include "helpers.container.render" (dict "value" . "name" $name "general" $general "context" $ "enableHealthCheckShorthand" true "enableMapPorts" true "useDefaultImage" false "autoPvcs" $autoPvcs) | indent 0 }}
      {{- else }}
containers:
        {{- range $idx, $ct := .containers }}
          {{- with $ct.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
          {{- else }}
- name: {{ printf "%s-%d" $name $idx }}
          {{- end }}
          {{- include "helpers.container.render" (dict "value" $ct "name" "" "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" true "autoPvcs" $autoPvcs) | indent 0 }}
        {{- end }}
      {{- end }}
      {{- $vols := include "helpers.volumes.renderVolume" (dict "value" . "general" $general "context" $ "autoPvcs" $autoPvcs) }}
volumes:{{- if eq (trim $vols) "[]" }} []{{- else }}{{ $vols }}{{- end }}
    {{- end -}}
  {{- end -}}
