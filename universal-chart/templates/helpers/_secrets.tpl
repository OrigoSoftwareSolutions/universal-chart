{{- define "helpers.secrets.includeEnv" -}}
  {{- $s := dict -}}
  {{- if typeIs "string" .value -}}
    {{- $s = fromYaml .value -}}
  {{- else if kindIs "map" .value -}}
    {{- $s = .value -}}
  {{- end -}}
  {{- range $envVarName, $ref := $s -}}
    {{- if kindIs "map" $ref }}
- name: {{ $envVarName }}
  valueFrom:
    secretKeyRef:
      name: {{ $ref.name }}
      key: {{ $ref.key }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.secrets.includeEnvSecret" -}}
  {{- range $i, $sName := .value }}
- secretRef:
    name: {{ $sName }}
  {{- end -}}
{{- end -}}

{{- define "helpers.secrets.encode" -}}
  {{if hasPrefix "b64:" .value}}{{trimPrefix "b64:" .value}}{{else}}{{toString .value|b64enc}}{{end}}
{{- end -}}

{{- define "helpers.secrets.render" -}}
  {{- $v := dict -}}
  {{- if kindIs "string" .value -}}
{{- $v = fromYaml .value }}
  {{- else -}}
{{- $v = .value }}
  {{- end -}}
  {{- range $key, $value := $v -}}
    {{- if kindIs "string" $value -}}
      {{- printf "\n%s: %s" $key (include "helpers.secrets.encode" (dict "value" $value)) -}}
    {{- else -}}
      {{- printf "\n%s: %s" $key ($value | toJson | b64enc) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
