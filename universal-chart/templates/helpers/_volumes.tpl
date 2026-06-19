{{- define "helpers.volumes.typed" -}}
  {{- $ctx := .context -}}
  {{- range .volumes -}}
    {{- $v := . -}}
    {{- if eq .type "configMap" }}
- name: {{ $v.name }}
      {{- $configMapName := $v.configMapName | default $v.originalName }}
  configMap:
      {{- with $configMapName }}
    name: {{ include "helpers.tplvalues.render" (dict "value" . "context" $ctx) }}
      {{- else }}
    name: {{ include "helpers.app.fullname" (dict "name" $v.name "context" $ctx) }}
      {{- end }}
      {{- with $v.defaultMode }}
    defaultMode: {{ . }}
      {{- end }}
      {{- with $v.items }}
    items: {{- include "helpers.tplvalues.render" (dict "value" . "context" $ctx) | nindent 4 }}
      {{- end }}
    {{- else if eq .type "secret" }}
- name: {{ $v.name }}
      {{- $secretName := $v.secretName | default $v.originalName }}
  secret:
      {{- with $secretName }}
    secretName: {{ include "helpers.tplvalues.render" (dict "value" . "context" $ctx) }}
      {{- else }}
    secretName: {{ include "helpers.app.fullname" (dict "name" $v.name "context" $ctx) }}
      {{- end }}
      {{- with $v.items }}
    items: {{- include "helpers.tplvalues.render" (dict "value" . "context" $ctx) | nindent 4 }}
      {{- end }}
    {{- else if eq .type "pvc" }}
- name: {{ $v.name }}
      {{- $claimName := $v.claimName | default $v.originalName }}
  persistentVolumeClaim:
      {{- with $claimName }}
    claimName: {{ include "helpers.tplvalues.render" (dict "value" . "context" $ctx) }}
      {{- else }}
    claimName: {{ include "helpers.app.fullname" (dict "name" $v.name "context" $ctx) }}
      {{- end }}
    {{- else if eq .type "emptyDir" }}
- name: {{ .name }}
      {{- if or .sizeLimit .medium }}
  emptyDir:
        {{- if .sizeLimit }}
    sizeLimit: {{ .sizeLimit }}
        {{- end }}
        {{- if .medium }}
    medium: {{ .medium }}
        {{- end }}
      {{- else }}
  emptyDir: {}
      {{- end }}
    {{- else if eq .type "hostPath" }}
- name: {{ .name }}
  hostPath:
    path: {{ .path }}
      {{- with .hostPathType }}
    type: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "helpers.volumes.renderVolume" -}}
  {{- $ctx := .context -}}
  {{- $val := .value -}}
  {{- if or (or $val.volumes $val.extraVolumes) (or $ctx.Values.defaults.extraVolumes $ctx.Values.defaults.volumes) }}
    {{- with $val.volumes }}
      {{ include "helpers.volumes.typed" ( dict "volumes" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.volumes }}
      {{ include "helpers.volumes.typed" ( dict "volumes" . "context" $ctx) }}
    {{- end }}
    {{- with $val.extraVolumes }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.extraVolumes }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
  {{- else }}
  []
  {{- end }}
{{- end -}}

{{- define "helpers.volumes.renderVolumeMounts" -}}
  {{- $ctx := .context -}}
  {{- $val := .value -}}
  {{- if or (or $val.volumeMounts $val.extraVolumeMounts) (or $ctx.Values.defaults.extraVolumeMounts $ctx.Values.defaults.volumeMounts) -}}
    {{- with $val.volumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.volumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.extraVolumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $val.extraVolumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
  {{- else }}  []{{- end -}}
  {{- end -}}
