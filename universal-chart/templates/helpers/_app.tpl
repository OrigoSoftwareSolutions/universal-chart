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
If .name is set, it's appended to the app name.
*/}}
{{- define "helpers.app.fullname" -}}
  {{- if .name -}}
    {{- printf "%s-%s" (include "helpers.app.name" .context) .name | trunc 63 | trimSuffix "-" -}}
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
{{- end }}

{{- define "helpers.app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helpers.app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Workload-specific selector labels. Includes base selectorLabels plus
app.kubernetes.io/component derived from the workload name.
Expects dict with: name (string), context ($ root).
*/}}
{{- define "helpers.app.workloadSelectorLabels" -}}
  {{- include "helpers.app.selectorLabels" .context }}
app.kubernetes.io/component: {{ .name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "helpers.app.defaultAnnotations" -}}{{- end -}}
