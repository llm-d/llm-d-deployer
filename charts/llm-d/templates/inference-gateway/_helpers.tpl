{{/*
Create a default fully qualified app name for inferenceGateway.
*/}}
{{- define "gateway.fullname" -}}
  {{- if .Values.gateway.fullnameOverride -}}
    {{- .Values.gateway.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default "inference-gateway" .Values.gateway.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Resolve gateway class name
*/}}
{{- define "gateway.className" -}}
  {{- if contains "gke-l7" .Values.gateway.gatewayClassName -}}
    {{- print .Values.gateway.gatewayClassName -}}
  {{- else -}}
    {{- .Values.gateway.gatewayClassName -}}
  {{- end -}}
{{- end -}}
