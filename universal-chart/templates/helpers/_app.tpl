{{- define "helpers.app.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helpers.app.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helpers.app.fullname" -}}
  {{- if .name -}}
    {{- if .context.Values.releasePrefix -}}
      {{- printf "%s-%s" .context.Values.releasePrefix .name | trunc 63 | trimAll "-" -}}
    {{- else -}}
      {{- printf "%s-%s" (include "helpers.app.name" .context) .name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- include "helpers.app.name" .context -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.app.labels" -}}
  {{ include "helpers.app.selectorLabels" . }}
helm.sh/chart: {{ include "helpers.app.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
  {{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
  {{- end }}
  {{- with .Values.defaults.labels }}
    {{ include "helpers.tplvalues.render" (dict "value" . "context" $) }}
  {{- end }}
{{- end }}

{{- define "helpers.app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helpers.app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
  {{- include "helpers.app.genericSelectorLabels" $ }}
{{- end }}

{{- define "helpers.app.genericSelectorLabels" -}}
  {{- with .Values.defaults.extraSelectorLabels }}
    {{ include "helpers.tplvalues.render" (dict "value" . "context" $) }}
  {{- end }}
{{- end }}

{{- define "helpers.app.defaultAnnotations" -}}
  {{- with .Values.defaults.annotations }}
    {{ include "helpers.tplvalues.render" (dict "value" . "context" $) }}
  {{- end }}
{{- end }}

{{/*
For a backward compatibility
TODO: remove it in version 3.x.x, use defaultHookAnnotations
*/}}
{{- define "helpers.app.hooksAnnotations" -}}
  {{ include "helpers.app.defaultHookAnnotations" .context | fromYaml }}
{{- end }}

{{/*
Template for default hook annotations for configmaps and secrets
*/}}
{{- define "helpers.app.defaultHookAnnotations" -}}
  {{- with .Values.defaults.hookAnnotations }}
    {{- include "helpers.tplvalues.render" ( dict "value" . "context" $ ) }}
  {{- end }}
{{- end }}

{{/*
Merge the user defined annotations and the common hook annotations
*/}}
{{- define "helpers.app.annotations" -}}
  {{- $defaultHookValues := include "helpers.app.defaultHookAnnotations" .context | fromYaml }}
  {{- $defaultAnnotations := include "helpers.app.defaultAnnotations" .context | fromYaml }}
  {{- $userValues := .value | fromYaml }}
  {{- $mergedValues := mustMergeOverwrite  $defaultHookValues $userValues $defaultAnnotations }}
{{- $mergedValues | toYaml -}}
{{- end -}}
