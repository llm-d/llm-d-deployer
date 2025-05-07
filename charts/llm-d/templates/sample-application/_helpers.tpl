{{/*
Define the model name to be used
*/}}
{{- define "sampleApplication.modelName" -}}
  {{- if .Values.sampleApplication.enabled -}}
    {{- if .Values.sampleApplication.model.pvc.enabled -}}
      {{- .Values.sampleApplication.model.pvc.modelName }}
    {{- else if .Values.sampleApplication.model.huggingface.enabled }}
      {{- .Values.sampleApplication.model.huggingface.modelName }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Sanitize the model name into a valid k8s label.
*/}}
{{- define "sampleApplication.sanitizedModelName" -}}
  {{- $name := include "sampleApplication.modelName" . | lower | trim -}}
  {{- $name = regexReplaceAll "[^a-z0-9_.-]" $name "-" -}}
  {{- $name = regexReplaceAll "^[\\-._]+" $name "" -}}
  {{- $name = regexReplaceAll "[\\-._]+$" $name "" -}}
  {{- $name = regexReplaceAll "\\." $name "-" -}}

  {{- if gt (len $name) 63 -}}
    {{- $name = substr 0 63 $name -}}
  {{- end -}}

{{- $name -}}
{{- end }}

{{/*
Define the template for ingress host
*/}}
{{- define "sampleApplication.ingressHost" -}}
  {{- if .Values.ingress.host -}}
    {{- include "common.tplvalues.render" ( dict "value" .Values.ingress.host "context" $ ) }}
  {{- else }}
    {{- include "gateway.fullname" . }}.{{ default "localhost" .Values.ingress.clusterRouterBase }}
  {{- end}}
{{- end}}



{{/*
Define the model artifact URI if using pvc for BYO model
*/}}
{{- define "sampleApplication.modelArtifactURI" -}}
{{- if .Values.sampleApplication.enabled -}}
{{- if .Values.sampleApplication.model.pvc.enabled -}}
pvc://{{ .Values.sampleApplication.model.pvc.modelArtifactURI }}
{{- else if .Values.sampleApplication.model.huggingface.enabled -}}
hf://{{ .Values.sampleApplication.model.huggingface.modelArtifactURI }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Define the model cache path for downloading models via huggingface
*/}}
{{- define "sampleApplication.huggingFaceCacheDir" -}}
{{- .Values.sampleApplication.model.huggingface.cache.path | default "/vllm-hf-models" }}
{{- end }}
