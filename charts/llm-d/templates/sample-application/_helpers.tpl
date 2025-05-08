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
Define the model cache path for downloading models via huggingface
*/}}
{{- define "sampleApplication.huggingFaceCacheDir" -}}
{{- .Values.sampleApplication.model.huggingface.cache.path | default "/vllm-hf-models" }}
{{- end }}

{{/*
Define a normalized modelServe path / repo id to include mountpath in .ModelPath when using pvc
(HACK MSVC2 - waiting on https://github.com/neuralmagic/llm-d-model-service/issues/110)
*/}}
{{- define "sampleApplication.modelServe" -}}
  {{- if .Values.sampleApplication.enabled -}}
    {{- if ( eq (include "sampleApplication.modelArtifactType" . ) "pvc" )  -}}
      {{- .Values.sampleApplication.model.pvc.mountPath }}/{{`{{ .ModelPath }}`}}
    {{- else if ( eq (include "sampleApplication.modelArtifactType" . ) "hf") -}}
      {{`{{ .HFModelName }}`}}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Define served model names for vllm
*/}}
{{- define "sampleApplication.servedModelNames" -}}
  {{- if .Values.sampleApplication.model.servedModelNames }}
    {{- $servedModelNames := join " " .Values.sampleApplication.model.servedModelNames -}}
    {{- include "sampleApplication.sanitizedModelName" . }} {{ $servedModelNames }}
  {{- else }}
    {{- include "sampleApplication.sanitizedModelName" . }}
  {{- end }}
{{- end }}
