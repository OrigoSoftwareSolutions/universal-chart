{{- define "helpers.capabilities.cronJob.apiVersion" -}}
{{- print "batch/v1" -}}
{{- end -}}

{{- define "helpers.capabilities.deployment.apiVersion" -}}
{{- print "apps/v1" -}}
{{- end -}}

{{- define "helpers.capabilities.statefulSet.apiVersion" -}}
{{- print "apps/v1" -}}
{{- end -}}

{{- define "helpers.capabilities.daemonSet.apiVersion" -}}
{{- print "apps/v1" -}}
{{- end -}}

{{- define "helpers.capabilities.pdb.apiVersion" -}}
{{- print "policy/v1" -}}
{{- end -}}

{{- define "helpers.capabilities.hpa.apiVersion" -}}
{{- print "autoscaling/v2" -}}
{{- end -}}

{{- define "helpers.capabilities.externalSecret.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "external-secrets.io/v1" -}}
{{- print "external-secrets.io/v1" -}}
  {{- else -}}
{{- print "external-secrets.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.certManager.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "cert-manager.io/v1" -}}
{{- print "cert-manager.io/v1" -}}
  {{- else -}}
{{- print "cert-manager.io/v1alpha2" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.gatewayApi.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1" -}}
{{- print "gateway.networking.k8s.io/v1" -}}
  {{- else -}}
{{- print "gateway.networking.k8s.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiogateway.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiovirtualservice.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiosecurity.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "security.istio.io/v1" -}}
{{- print "security.istio.io/v1" -}}
  {{- else -}}
{{- print "security.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{- define "helpers.capabilities.istiodestinationrule.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "networking.istio.io/v1" -}}
{{- print "networking.istio.io/v1" -}}
  {{- else -}}
{{- print "networking.istio.io/v1beta1" -}}
  {{- end -}}
{{- end -}}
