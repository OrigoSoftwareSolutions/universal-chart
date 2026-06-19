{{- define "helpers.workload.metadata" -}}
  {{- $context := .context -}}
  {{- $value := .value -}}
  {{- $extraAnnotations := .extraAnnotations -}}
labels:
  {{- include "helpers.app.labels" $context | nindent 2 }}
  {{- with $value.labels }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
  {{- $annots := include "helpers.app.defaultAnnotations" $context | trim }}
  {{- if or $extraAnnotations (or $annots $value.annotations) }}
annotations:
    {{- with $extraAnnotations }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
    {{- if $annots }}{{ $annots | nindent 2 }}{{- end }}
    {{- with $value.annotations }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
  {{- end }}
{{- end -}}

{{- define "helpers.workload.podTemplateMetadata" -}}
  {{- $context := .context -}}
  {{- $value := .value -}}
  {{- $selectorLabels := .selectorLabels | default false -}}
  {{- $extraSelectorLabels := .extraSelectorLabels -}}
  {{- $autoChecksums := include "helpers.workload.autoChecksums" (dict "name" .name "value" $value "context" $context) | trim -}}
  {{- if or $selectorLabels (or $extraSelectorLabels (or $context.Values.defaults.podLabels $value.podLabels)) }}labels:
    {{- if $selectorLabels }}{{- include "helpers.app.workloadSelectorLabels" (dict "name" .name "context" $context) | nindent 2 }}{{- end }}
    {{- with $extraSelectorLabels }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
    {{- with $context.Values.defaults.podLabels }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
    {{- with $value.podLabels }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
  {{- end }}
  {{- if or $context.Values.defaults.podAnnotations (or $value.podAnnotations $autoChecksums) }}
annotations:
    {{- with $context.Values.defaults.podAnnotations }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
    {{- with $value.podAnnotations }}{{- include "helpers.tplvalues.render" (dict "value" . "context" $context) | nindent 2 }}{{- end }}
    {{- if $autoChecksums }}{{ $autoChecksums | nindent 2 }}{{- end }}
  {{- end }}
{{- end -}}
