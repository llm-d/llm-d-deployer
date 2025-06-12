{{/*
Create a default fully qualified app name for modelservice.
*/}}
{{- define "modelservice.fullname" -}}
  {{- if .Values.modelservice.fullnameOverride -}}
    {{- .Values.modelservice.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default "modelservice" .Values.modelservice.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Return the proper image name for modelservice.
*/}}
{{- define "modelservice.image" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.modelservice.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name for endpoint picker
*/}}
{{- define "modelservice.eppImage" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.modelservice.epp.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name for vllm
*/}}
{{- define "modelservice.vllmImage" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.modelservice.vllm.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name for routing proxy
*/}}
{{- define "modelservice.routingProxyImage" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.modelservice.routingProxy.image "global" .Values.global) }}
{{- end -}}

{{/*
Create the name of the service account to use for modelservice.
*/}}
{{- define "modelservice.serviceAccountName" -}}
  {{- if .Values.modelservice.serviceAccount.fullnameOverride -}}
    {{- .Values.modelservice.serviceAccount.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default (include "modelservice.fullname" .) .Values.modelservice.serviceAccount.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "modelservice.renderImagePullSecrets" -}}
  {{- include "common.images.renderPullSecrets" (dict "images" (list .Values.modelservice.image) "context" $) -}}
{{- end -}}

{{/*
Return the proper image name for vllm sim
*/}}
{{- define "modelservice.inferenceSimulatorImage" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.modelservice.inferenceSimulator.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "inferenceSimulator.renderImagePullSecrets" -}}
  {{- include "common.images.renderPullSecrets" (dict "images" (list .Values.modelservice.inferenceSimulator.image) "context" $) -}}
{{- end -}}


{{- define "common.images.renderImagePullSecretsString" -}}
  {{- $pullSecrets := list }}
  {{- $context := .context }}

  {{- range (($context.Values.global).imagePullSecrets) -}}
    {{- if kindIs "map" . -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
    {{- else -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- range .pullSecrets -}}
      {{- if kindIs "map" . -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
      {{- else -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- join "," ($pullSecrets | uniq) | quote }}
{{- end }}

{{- define "modelservice.epp.envList" -}}
  {{- $env := dict }}
  {{- range .Values.modelservice.epp.defaultEnvVars }}
    {{- $_ := set $env (include "common.tplvalues.render" ( dict "value" .name "context" $ )) (include "common.tplvalues.render" ( dict "value" .value "context" $ ))}}
  {{- end }}
  {{- range  .Values.modelservice.epp.defaultEnvVarsOverride }}
    {{- $_ := set $env (include "common.tplvalues.render" ( dict "value" .name "context" $ )) (include "common.tplvalues.render" ( dict "value" .value "context" $ ))}}
  {{- end }}
{{- range $k, $v := $env }}
- name: {{ $k }}
  value: {{ $v }}
{{- end }}
{{- end }}

{{/*
Return the RunAI Streamer environment variables when loadFormat is runai_streamer
*/}}
{{- define "modelservice.runaiStreamer.envVars" -}}
{{- if or (eq .Values.modelservice.vllm.loadFormat "runai_streamer") (eq .Values.modelservice.vllm.loadFormat "runai_streamer_sharded") }}
- name: RUNAI_STREAMER_CONCURRENCY
  value: {{ .Values.modelservice.vllm.runaiStreamer.concurrency | quote }}
{{- if .Values.modelservice.vllm.runaiStreamer.chunkBytesize }}
- name: RUNAI_STREAMER_CHUNK_BYTESIZE
  value: {{ .Values.modelservice.vllm.runaiStreamer.chunkBytesize | quote }}
{{- end }}
- name: RUNAI_STREAMER_MEMORY_LIMIT
  value: {{ .Values.modelservice.vllm.runaiStreamer.memoryLimit | quote }}
{{- if .Values.modelservice.vllm.runaiStreamer.s3.endpointUrl }}
- name: AWS_ENDPOINT_URL
  value: {{ .Values.modelservice.vllm.runaiStreamer.s3.endpointUrl | quote }}
{{- end }}
{{- if .Values.modelservice.vllm.runaiStreamer.s3.caBundlePath }}
- name: AWS_CA_BUNDLE
  value: {{ .Values.modelservice.vllm.runaiStreamer.s3.caBundlePath | quote }}
{{- end }}
- name: RUNAI_STREAMER_S3_USE_VIRTUAL_ADDRESSING
  value: {{ .Values.modelservice.vllm.runaiStreamer.s3.useVirtualAddressing | ternary "1" "0" }}
{{- end }}
{{- end }}

{{/*
Return the RunAI Streamer extra config args for model-loader-extra-config
*/}}
{{- define "modelservice.runaiStreamer.extraConfigArgs" -}}
{{- if or (eq .Values.modelservice.vllm.loadFormat "runai_streamer") (eq .Values.modelservice.vllm.loadFormat "runai_streamer_sharded") }}
{{- $config := dict }}
{{- if .Values.modelservice.vllm.runaiStreamer.concurrency }}
  {{- $_ := set $config "concurrency" .Values.modelservice.vllm.runaiStreamer.concurrency }}
{{- end }}
{{- if .Values.modelservice.vllm.runaiStreamer.memoryLimit }}
  {{- $_ := set $config "memory_limit" .Values.modelservice.vllm.runaiStreamer.memoryLimit }}
{{- end }}
{{- if .Values.modelservice.vllm.runaiStreamer.pattern }}
  {{- $_ := set $config "pattern" .Values.modelservice.vllm.runaiStreamer.pattern }}
{{- end }}
{{- if $config }}
- "--model-loader-extra-config"
- {{ $config | toJson | quote }}
{{- end }}
{{- end }}
{{- end }}
