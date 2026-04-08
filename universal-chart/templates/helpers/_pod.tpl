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
    {{- else if (ne $.Values.defaults.serviceAccountName nil) }}
      {{- with $.Values.defaults.serviceAccountName }}
serviceAccountName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- if (ne .hostAliases nil) }}
      {{- with .hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.hostAliases nil) }}
      {{- with $general.hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.hostAliases nil) }}
      {{- with $.Values.defaults.hostAliases }}
hostAliases: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
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
    {{- else if (ne $.Values.defaults.priorityClassName nil) }}
      {{- with $.Values.defaults.priorityClassName }}
priorityClassName: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- if (ne .dnsPolicy nil) }}
      {{- with .dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.dnsPolicy nil) }}
      {{- with $general.dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.dnsPolicy nil) }}
      {{- with $.Values.defaults.dnsPolicy }}
dnsPolicy: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- with .dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- else with $general.dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- else with $.Values.defaults.dnsConfig }}
dnsConfig:
      {{- toYaml . | nindent 2 }}
    {{- end }}
    {{- if (ne .nodeSelector nil) }}
      {{- with .nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.nodeSelector nil) }}
      {{- with $general.nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.nodeSelector nil) }}
      {{- with $.Values.defaults.nodeSelector }}
nodeSelector: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
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
    {{- else if (ne $.Values.defaults.tolerations nil) }}
      {{- with $.Values.defaults.tolerations }}
tolerations:
        {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne .topologySpreadConstraints nil) }}
      {{- with .topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $general.topologySpreadConstraints nil) }}
      {{- with $general.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.topologySpreadConstraints nil) }}
      {{- with $.Values.defaults.topologySpreadConstraints }}
topologySpreadConstraints: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}

    {{- if (ne $podSecurityContext nil) }}
      {{- with $podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $generalPodSecurityContext nil) }}
      {{- with $generalPodSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- else if (ne $.Values.defaults.podSecurityContext nil) }}
      {{- with $.Values.defaults.podSecurityContext }}
securityContext: {{- include "helpers.tplvalues.render" (dict "value" . "context" $) | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- $pullSecrets := concat ($.Values.imagePullSecrets | default list) ($.Values.defaults.extraImagePullSecrets | default list) (.imagePullSecrets | default list) (.extraImagePullSecrets | default list) | uniq -}}
    {{- if $pullSecrets }}
imagePullSecrets:
      {{- range $pullSecrets }}
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
    {{- if (ne .hostNetwork nil) }}
hostNetwork: {{ .hostNetwork }}
    {{- else if (ne $general.hostNetwork nil) }}
hostNetwork: {{ $general.hostNetwork }}
    {{- else if (ne $.Values.defaults.hostNetwork nil) }}
hostNetwork: {{ $.Values.defaults.hostNetwork }}
    {{- end }}
    {{- if (ne .hostPID nil) }}
hostPID: {{ .hostPID }}
    {{- else if (ne $general.hostPID nil) }}
hostPID: {{ $general.hostPID }}
    {{- else if (ne $.Values.defaults.hostPID nil) }}
hostPID: {{ $.Values.defaults.hostPID }}
    {{- end }}
    {{- if (ne .hostIPC nil) }}
hostIPC: {{ .hostIPC }}
    {{- else if (ne $general.hostIPC nil) }}
hostIPC: {{ $general.hostIPC }}
    {{- else if (ne $.Values.defaults.hostIPC nil) }}
hostIPC: {{ $.Values.defaults.hostIPC }}
    {{- end }}
    {{- if (ne .shareProcessNamespace nil) }}
shareProcessNamespace: {{ .shareProcessNamespace }}
    {{- else if (ne $general.shareProcessNamespace nil) }}
shareProcessNamespace: {{ $general.shareProcessNamespace }}
    {{- else if (ne $.Values.defaults.shareProcessNamespace nil) }}
shareProcessNamespace: {{ $.Values.defaults.shareProcessNamespace }}
    {{- end }}
    {{- if (ne .automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ .automountServiceAccountToken }}
    {{- else if (ne $general.automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ $general.automountServiceAccountToken }}
    {{- else if (ne $.Values.defaults.automountServiceAccountToken nil) }}
automountServiceAccountToken: {{ $.Values.defaults.automountServiceAccountToken }}
    {{- end }}
    {{- if (ne .runtimeClassName nil) }}
runtimeClassName: {{ .runtimeClassName }}
    {{- else if (ne $general.runtimeClassName nil) }}
runtimeClassName: {{ $general.runtimeClassName }}
    {{- else if (ne $.Values.defaults.runtimeClassName nil) }}
runtimeClassName: {{ $.Values.defaults.runtimeClassName }}
    {{- end }}
    {{- if (ne .overhead nil) }}
overhead: {{- include "helpers.tplvalues.render" (dict "value" .overhead "context" $) | nindent 2 }}
    {{- else if (ne $general.overhead nil) }}
overhead: {{- include "helpers.tplvalues.render" (dict "value" $general.overhead "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .readinessGates nil) }}
readinessGates: {{- include "helpers.tplvalues.render" (dict "value" .readinessGates "context" $) | nindent 2 }}
    {{- else if (ne $general.readinessGates nil) }}
readinessGates: {{- include "helpers.tplvalues.render" (dict "value" $general.readinessGates "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .schedulingGates nil) }}
schedulingGates: {{- include "helpers.tplvalues.render" (dict "value" .schedulingGates "context" $) | nindent 2 }}
    {{- else if (ne $general.schedulingGates nil) }}
schedulingGates: {{- include "helpers.tplvalues.render" (dict "value" $general.schedulingGates "context" $) | nindent 2 }}
    {{- end }}
    {{- if (ne .os nil) }}
os: {{- include "helpers.tplvalues.render" (dict "value" .os "context" $) | nindent 2 }}
    {{- else if (ne $general.os nil) }}
os: {{- include "helpers.tplvalues.render" (dict "value" $general.os "context" $) | nindent 2 }}
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
        {{- include "helpers.container.render" (dict "value" $ic "name" "" "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" false "workloadContainerSecurityContext" $workloadContainerSecCtx "isInitContainer" true) | indent 0 }}
      {{- end }}{{- end }}
      {{- if not .containers }}
containers:
- name: {{ $name }}
        {{- include "helpers.container.render" (dict "value" . "name" $name "workloadName" $name "general" $general "context" $ "enableHealthCheckShorthand" true "enableMapPorts" true "useDefaultImage" true "autoPvcs" $autoPvcs "workloadContainerSecurityContext" .containerSecurityContext) | indent 0 }}
      {{- else }}
containers:
        {{- range $idx, $ct := .containers }}
          {{- with $ct.name }}
- name: {{ include "helpers.tplvalues.render" ( dict "value" . "context" $) }}
          {{- else }}
- name: {{ printf "%s-%d" ($name | trunc 58 | trimSuffix "-") $idx }}
          {{- end }}
          {{- include "helpers.container.render" (dict "value" $ct "name" "" "workloadName" $name "general" $general "context" $ "enableHealthCheckShorthand" false "enableMapPorts" false "useDefaultImage" false "autoPvcs" $autoPvcs "workloadContainerSecurityContext" $workloadContainerSecCtx) | indent 0 }}
        {{- end }}
      {{- end }}
      {{- $vols := include "helpers.volumes.renderVolume" (dict "value" . "general" $general "context" $ "name" $name "autoPvcs" $autoPvcs) }}
volumes:{{- if eq (trim $vols) "[]" }} []{{- else }}
{{ regexReplaceAll "\n{2,}" ($vols | trim) "\n" }}{{- end }}
    {{- end -}}
  {{- end -}}
