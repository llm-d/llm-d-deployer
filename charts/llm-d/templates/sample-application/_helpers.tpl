{{/*
Sanitize the model name into a valid k8s label.
*/}}
{{- define "sampleApplication.sanitizedModelName" -}}
  {{- $name := .Values.sampleApplication.modelName | lower | trim -}}
  {{- $name = regexReplaceAll "[^a-z0-9_.-]" $name "-" -}}
  {{- $name = regexReplaceAll "^[\\-._]+" $name "" -}}
  {{- $name = regexReplaceAll "[\\-._]+$" $name "" -}}
  {{- $name = regexReplaceAll "\\." $name "-" -}}

  {{- if gt (len $name) 63 -}}
    {{- $name = substr 0 63 $name -}}
  {{- end -}}

{{- $name -}}
{{- end }}


{{- define "sampleApplication.ingressHost" -}}
  {{- if .Values.ingress.host -}}
    {{- include "common.tplvalues.render" ( dict "value" .Values.ingress.host "context" $ ) }}
  {{- else }}
    {{- include "gateway.fullname" . }}.{{ default "localhost" .Values.ingress.clusterRouterBase }}
  {{- end}}
{{- end }}
