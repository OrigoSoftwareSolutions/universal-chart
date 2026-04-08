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

{{- define "helpers.volumes.autoPvcVolumes" -}}
  {{- $ctx := .context -}}
  {{- $workloadName := .name -}}
  {{- range $name, $p := $ctx.Values.pvcs -}}
    {{- if and (not ($p.disabled | default false)) (or (not (hasKey $p "workloads")) (eq $p.workloads nil) (has $workloadName $p.workloads)) }}
- name: {{ $name }}
  persistentVolumeClaim:
    claimName: {{ include "helpers.app.fullname" (dict "name" $name "context" $ctx) }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "helpers.volumes.autoPvcMounts" -}}
  {{- $ctx := .context -}}
  {{- $workloadName := .name -}}
  {{- range $name, $p := $ctx.Values.pvcs -}}
    {{- if and (not ($p.disabled | default false)) $p.mountPath (or (not (hasKey $p "workloads")) (eq $p.workloads nil) (has $workloadName $p.workloads)) }}
- name: {{ $name }}
  mountPath: {{ $p.mountPath }}
      {{- with $p.subPath }}
  subPath: {{ . }}
      {{- end }}
      {{- with $p.subPathExpr }}
  subPathExpr: {{ . }}
      {{- end }}
      {{- with $p.readOnly }}
  readOnly: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "helpers.volumes.renderVolume" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $val := .value -}}
  {{- $name := .name -}}
  {{- $autoPvcs := .autoPvcs | default false -}}
  {{- $hasAutoPvcs := false -}}
  {{- if $autoPvcs }}{{- range $pvcName, $p := $ctx.Values.pvcs -}}{{- if and (not ($p.disabled | default false)) (or (not (hasKey $p "workloads")) (eq $p.workloads nil) (has $name $p.workloads)) }}{{ $hasAutoPvcs = true }}{{- end }}{{- end }}{{- end -}}
  {{- if or $hasAutoPvcs (or (or $val.volumes $val.extraVolumes) (or (or $general.extraVolumes $ctx.Values.defaults.extraVolumes) (or $general.volumes $ctx.Values.defaults.volumes))) }}
    {{- with $val.volumes }}
      {{ include "helpers.volumes.typed" ( dict "volumes" . "context" $ctx) }}
    {{- end }}
    {{- with $general.volumes }}
      {{ include "helpers.volumes.typed" ( dict "volumes" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.volumes }}
      {{ include "helpers.volumes.typed" ( dict "volumes" . "context" $ctx) }}
    {{- end }}
    {{- with $val.extraVolumes }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $general.extraVolumes }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.extraVolumes }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- if $hasAutoPvcs }}
      {{ include "helpers.volumes.autoPvcVolumes" (dict "context" $ctx "name" $name) }}
    {{- end }}
  {{- else }}
  []
  {{- end }}
{{- end -}}

{{- define "helpers.volumes.renderVolumeMounts" -}}
  {{- $ctx := .context -}}
  {{- $general := .general -}}
  {{- $val := .value -}}
  {{- $name := .name -}}
  {{- $autoPvcs := .autoPvcs | default false -}}
  {{- $hasAutoPvcMounts := false -}}
  {{- if $autoPvcs }}{{- range $pvcName, $p := $ctx.Values.pvcs -}}{{- if and (not ($p.disabled | default false)) $p.mountPath (or (not (hasKey $p "workloads")) (eq $p.workloads nil) (has $name $p.workloads)) }}{{ $hasAutoPvcMounts = true }}{{- end }}{{- end }}{{- end -}}
  {{- if or $hasAutoPvcMounts (or (or $val.volumeMounts $general.extraVolumeMounts) (or $ctx.Values.defaults.extraVolumeMounts (or $general.volumeMounts $ctx.Values.defaults.volumeMounts))) -}}
    {{- with $val.volumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $general.volumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $general.extraVolumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.volumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- with $ctx.Values.defaults.extraVolumeMounts }}
      {{ include "helpers.tplvalues.render" ( dict "value" . "context" $ctx) }}
    {{- end }}
    {{- if $hasAutoPvcMounts }}
      {{ include "helpers.volumes.autoPvcMounts" (dict "context" $ctx "name" $name) }}
    {{- end }}
  {{- else }}  []{{- end -}}
  {{- end -}}
