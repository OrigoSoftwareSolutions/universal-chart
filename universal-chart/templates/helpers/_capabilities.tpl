{{- define "helpers.capabilities.helmVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.helmVersion }}
{{- .Values.global.helmVersion -}}
    {{- else -}}
      {{- if typeIs "string" .Capabilities.KubeVersion -}}
{{- "v2" -}}
      {{- else -}}
{{- "v3" -}}
      {{- end -}}
    {{- end -}}
  {{- else }}
    {{- if typeIs "string" .Capabilities.KubeVersion -}}
{{- "v2" -}}
    {{- else -}}
{{- "v3" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.kubeVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.kubeVersion }}
{{- .Values.global.kubeVersion -}}
    {{- else }}
      {{- if semverCompare "<3" (include "helpers.capabilities.helmVersion" $) -}}
{{- default .Capabilities.KubeVersion .Values.kubeVersion -}}
      {{- else -}}
{{- default .Capabilities.KubeVersion.Version .Values.kubeVersion -}}
      {{- end -}}
    {{- end -}}
  {{- else }}
    {{- if .Capabilities.KubeVersion.Version -}}
{{- default .Capabilities.KubeVersion.Version .Values.kubeVersion -}}
    {{- else -}}
{{- default .Capabilities.KubeVersion .Values.kubeVersion -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.cronJob.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.cronJob }}
{{- .Values.global.apiVersions.cronJob -}}
    {{- else if semverCompare "<1.21-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "batch/v1beta1" -}}
    {{- else -}}
{{- print "batch/v1" -}}
    {{- end -}}
  {{- else if semverCompare "<1.21-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "batch/v1beta1" -}}
  {{- else -}}
{{- print "batch/v1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.deployment.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.deployment }}
{{- .Values.global.apiVersions.deployment -}}
    {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "extensions/v1beta1" -}}
    {{- else -}}
{{- print "apps/v1" -}}
    {{- end -}}
  {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "extensions/v1beta1" -}}
  {{- else -}}
{{- print "apps/v1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.statefulSet.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.statefulSet }}
{{- .Values.global.apiVersions.statefulSet -}}
    {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "apps/v1beta1" -}}
    {{- else -}}
{{- print "apps/v1" -}}
    {{- end -}}
  {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "apps/v1beta1" -}}
  {{- else -}}
{{- print "apps/v1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.daemonSet.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.daemonSet }}
{{- .Values.global.apiVersions.daemonSet -}}
    {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "extensions/v1beta1" -}}
    {{- else -}}
{{- print "apps/v1" -}}
    {{- end -}}
  {{- else if semverCompare "<1.14-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "extensions/v1beta1" -}}
  {{- else -}}
{{- print "apps/v1" -}}
  {{- end -}}
{{- end -}}


{{- define "helpers.capabilities.pdb.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.pdb }}
{{- .Values.global.apiVersions.pdb -}}
    {{- else if semverCompare "<1.21-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "policy/v1beta1" -}}
    {{- else -}}
{{- print "policy/v1" -}}
    {{- end -}}
  {{- else if semverCompare "<1.21-0" (include "helpers.capabilities.kubeVersion" $) -}}
{{- print "policy/v1beta1" -}}
  {{- else -}}
{{- print "policy/v1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiogateway.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.istioGateway }}
{{- .Values.global.apiVersions.istioGateway -}}
    {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
    {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
    {{- end -}}
  {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiovirtualservice.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.istioVirtualService }}
{{- .Values.global.apiVersions.istioVirtualService -}}
    {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
    {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
    {{- end -}}
  {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiosecurity.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.istioSecurity }}
{{- .Values.global.apiVersions.istioSecurity -}}
    {{- else if .Capabilities.APIVersions.Has "security.istio.io/v1" -}}
{{- print "security.istio.io/v1" -}}
    {{- else -}}
{{- print "security.istio.io/v1beta1" -}}
    {{- end -}}
  {{- else if .Capabilities.APIVersions.Has "security.istio.io/v1" -}}
{{- print "security.istio.io/v1" -}}
  {{- else -}}
{{- print "security.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiodestinationrule.apiVersion" -}}
  {{- if .Values.global }}
    {{- if .Values.global.apiVersions.istioDestinationRule }}
{{- .Values.global.apiVersions.istioDestinationRule -}}
    {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
    {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
    {{- end -}}
  {{- else if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}
