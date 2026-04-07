{{- define "helpers.deprecation.notice" -}}
** NOTICE **

Option `extraVolumeMounts` for generics and workloads generals has been renamed to `volumeMounts` and will be removed in the version 3.0.
Please use `volumeMounts` instead.

Option `imagePullSecrets` for workloads deprecated and will be removed in the version 3.0.
Please use `extraImagePullSecrets` instead.

Option `servicemonitors` has been renamed to `serviceMonitors` and will be removed in the version 3.0.
Please use `serviceMonitors` instead.

** WARNING **

Option `defaults.usePredefinedAffinity` will change default value to `false` in the version 3.0.
Please set this option in your values file or use `usePredefinedAffinity` in workloads generals.

Option `securityContext` for workloads and workload generals has been renamed to `podSecurityContext` and will be removed in the version 3.0.
Please use `podSecurityContext` instead.
{{- end }}


{{- define "helpers.deprecation.workload.imagePullSecrets" -}}
  {{- range $name, $wkl := .Values.deployments }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for deployment "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.hooks }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for hook "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.cronJobs }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for cronjob "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.jobs }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for job "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.statefulSets }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for statefulset "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.daemonSets }}{{- if $wkl.imagePullSecrets }}

** WARNING **

You use deprecated option `imagePullSecrets` for daemonset "{{$name}}". Please use `extraImagePullSecrets` instead.
  {{- end }}{{ end }}
{{ end }}

{{- define "helpers.deprecation.serviceMonitors" -}}
  {{- if .Values.servicemonitors }}

** WARNING **

You use deprecated option `servicemonitors`. Please use `serviceMonitors` instead.
  {{- end }}
{{ end }}

{{- define "helpers.deprecation.extraVolumeMounts" -}}
  {{- if .Values.defaults.extraVolumeMounts }}

** WARNING **

You use deprecated option `defaults.extraVolumeMounts`. Please use `defaults.volumeMounts` instead.
  {{- end }}
  {{- if .Values.deploymentsGeneral.extraVolumeMounts }}

** WARNING **

You use deprecated option `deploymentsGeneral.extraVolumeMounts`. Please use `deploymentsGeneral.volumeMounts` instead.
  {{- end }}
  {{- if .Values.statefulSetsGeneral.extraVolumeMounts }}

** WARNING **

You use deprecated option `statefulSetsGeneral.extraVolumeMounts`. Please use `statefulSetsGeneral.volumeMounts` instead.
  {{- end }}
  {{- if .Values.hooksGeneral.extraVolumeMounts }}

** WARNING **

You use deprecated option `hooksGeneral.extraVolumeMounts`. Please use `hooksGeneral.volumeMounts` instead.
  {{- end }}
  {{- if .Values.cronJobsGeneral.extraVolumeMounts }}

** WARNING **

You use deprecated option `cronJobsGeneral.extraVolumeMounts`. Please use `cronJobsGeneral.volumeMounts` instead.
  {{- end }}
  {{- if .Values.jobsGeneral.extraVolumeMounts }}

** WARNING **

You use deprecated option `jobsGeneral.extraVolumeMounts`. Please use `jobsGeneral.volumeMounts` instead.
  {{- end }}
{{ end }}

{{- define "helpers.deprecation.securityContext" -}}
  {{- range $name, $wkl := .Values.deployments }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for deployment "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.statefulSets }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for statefulset "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.daemonSets }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for daemonset "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.cronJobs }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for cronjob "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.jobs }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for job "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- range $name, $wkl := .Values.hooks }}{{- if $wkl.securityContext }}

** WARNING **

You use deprecated option `securityContext` for hook "{{$name}}". Please use `podSecurityContext` instead.
  {{- end }}{{ end }}
  {{- if .Values.deploymentsGeneral.securityContext }}

** WARNING **

You use deprecated option `deploymentsGeneral.securityContext`. Please use `deploymentsGeneral.podSecurityContext` instead.
  {{- end }}
  {{- if .Values.statefulSetsGeneral.securityContext }}

** WARNING **

You use deprecated option `statefulSetsGeneral.securityContext`. Please use `statefulSetsGeneral.podSecurityContext` instead.
  {{- end }}
  {{- if .Values.daemonSetsGeneral.securityContext }}

** WARNING **

You use deprecated option `daemonSetsGeneral.securityContext`. Please use `daemonSetsGeneral.podSecurityContext` instead.
  {{- end }}
  {{- if .Values.cronJobsGeneral.securityContext }}

** WARNING **

You use deprecated option `cronJobsGeneral.securityContext`. Please use `cronJobsGeneral.podSecurityContext` instead.
  {{- end }}
  {{- if .Values.jobsGeneral.securityContext }}

** WARNING **

You use deprecated option `jobsGeneral.securityContext`. Please use `jobsGeneral.podSecurityContext` instead.
  {{- end }}
  {{- if .Values.hooksGeneral.securityContext }}

** WARNING **

You use deprecated option `hooksGeneral.securityContext`. Please use `hooksGeneral.podSecurityContext` instead.
  {{- end }}
{{ end }}
