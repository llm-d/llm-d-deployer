{{/*
Sanitize the model name into a valid k8s label.
*/}}
{{- define "sampleApplication.sanitizedModelName" -}}
  {{- $name := .Values.sampleApplication.model.modelName | lower | trim -}}
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
Define the type of the modelArtifactURI
(Used in MSVC - will be removed once templating in MSVC supported)
*/}}
{{- define "sampleApplication.modelArtifactType" -}}
  {{- if hasPrefix "pvc://" .Values.sampleApplication.model.modelArtifactURI -}}
    pvc
  {{- else if hasPrefix "hf://" .Values.sampleApplication.model.modelArtifactURI -}}
    hf
  {{- else }}
    {{- fail "Values.sampleApplication.model.modelArtifactURI supports hf:// and pvc://" }}
  {{- end }}
{{- end }}

{{/*
Define served model names for vllm
*/}}
{{- define "sampleApplication.servedModelNames" -}}
  {{- .Values.sampleApplication.model.modelName }} {{ join " " .Values.sampleApplication.model.servedModelNames -}}
{{- end }}
