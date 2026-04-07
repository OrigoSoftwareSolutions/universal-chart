{{- define "helpers.tplvalues.render" -}}
  {{- $rendered := "" -}}
  {{- if typeIs "string" .value -}}
    {{- $rendered = .value -}}
  {{- else -}}
    {{- $rendered = (.value | toYaml) -}}
  {{- end -}}
  {{- if contains "{{" $rendered -}}
    {{- tpl $rendered .context -}}
  {{- else -}}
    {{- $rendered -}}
  {{- end -}}
{{- end -}}
