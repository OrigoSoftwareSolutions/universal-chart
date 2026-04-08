{{- define "helpers.configmaps.decode" -}}
  {{if hasPrefix "b64:" .value}}{{trimPrefix "b64:" .value | b64dec | quote }}{{else}}{{ quote .value }}{{- end }}
{{- end -}}


{{- define "helpers.configmaps.renderConfigMap" -}}
  {{- $v := dict -}}
  {{- if typeIs "string" .value -}}
{{- $v = fromYaml .value -}}
  {{- else if kindIs "map" .value -}}
{{- $v = .value -}}
  {{- end -}}
  {{- range $key, $value := $v -}}
    {{- if eq (typeOf $value) "float64" -}}
      {{- printf "\n%s: %s" $key ($value | toString | quote) -}}
    {{- else if empty $value -}}
      {{- printf "\n%s: %s" $key ("" | quote) -}}
    {{- else if kindIs "string" $value -}}
      {{- printf "\n%s: %s" $key (include "helpers.configmaps.decode" (dict "value" $value)) -}}
    {{- else -}}
      {{- printf "\n%s: %s" $key ($value | toJson | quote) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.configmaps.includeEnv" -}}
  {{- $ctx := .context -}}
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
    configMapKeyRef:
      name: {{ include "helpers.app.fullname" (dict "name" $ref.name "context" $ctx) }}
      key: {{ $ref.key }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.configmaps.includeEnvConfigmap" -}}
  {{- $ctx := .context -}}
  {{- range $i, $sName := .value }}
- configMapRef:
    name: {{ include "helpers.app.fullname" (dict "name" $sName "context" $ctx) }}
  {{- end -}}
{{- end -}}
