
# llm-d-vllm

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1](https://img.shields.io/badge/AppVersion-0.1-informational?style=flat-square)

vLLM model serving components for llm-d (separated from inference gateway)

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| llm-d |  | <https://github.com/llm-d/llm-d-deployer> |

## Source Code

* <https://github.com/llm-d/llm-d-deployer>

## Requirements

Kubernetes: `>= 1.30.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | common | 2.27.0 |
| https://charts.bitnami.com/bitnami | redis | 20.13.4 |

## Values

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| clusterDomain | Default Kubernetes cluster domain | string | `"cluster.local"` |
| commonAnnotations | Annotations to add to all deployed objects | object | `{}` |
| commonLabels | Labels to add to all deployed objects | object | `{}` |
| extraDeploy | Array of extra objects to deploy with the release | list | `[]` |
| fullnameOverride | String to fully override common.names.fullname | string | `""` |
| inferencePool | Integration with upstream inference gateway | object | `{"enabled":false,"modelServerType":"vllm","modelServers":{"matchLabels":{"app":"llm-d-vllm"}},"targetPort":8000}` |
| inferencePool.enabled | Enable integration with upstream inferencepool chart | bool | `false` |
| inferencePool.modelServerType | Model server type (vllm or triton-tensorrt-llm) | string | `"vllm"` |
| inferencePool.modelServers | Labels to match model servers | object | `{"matchLabels":{"app":"llm-d-vllm"}}` |
| inferencePool.targetPort | Target port for model servers | int | `8000` |
| kubeVersion | Override Kubernetes version | string | `""` |
| modelservice | Model service controller configuration | object | `{"enabled":true,"epp":{"image":{"imagePullPolicy":"Always","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d-inference-scheduler","tag":"0.0.4"}},"image":{"imagePullPolicy":"Always","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d-model-service","tag":"0.0.10"},"rbac":{"create":true},"replicas":1,"service":{"enabled":true,"port":8443,"type":"ClusterIP"},"serviceAccount":{"annotations":{},"create":true,"labels":{}},"vllm":{"extraArgs":[],"extraEnvVars":[],"image":{"imagePullPolicy":"IfNotPresent","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d","tag":"0.0.8"},"loadFormat":"","logLevel":"INFO"}}` |
| modelservice.enabled | Toggle to deploy modelservice controller related resources | bool | `true` |
| modelservice.epp | Endpoint picker configuration | object | `{"image":{"imagePullPolicy":"Always","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d-inference-scheduler","tag":"0.0.4"}}` |
| modelservice.image | Model Service controller image | object | `{"imagePullPolicy":"Always","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d-model-service","tag":"0.0.10"}` |
| modelservice.rbac | RBAC configuration | object | `{"create":true}` |
| modelservice.replicas | Number of controller replicas | int | `1` |
| modelservice.service | Service configuration | object | `{"enabled":true,"port":8443,"type":"ClusterIP"}` |
| modelservice.serviceAccount | Service Account Configuration | object | `{"annotations":{},"create":true,"labels":{}}` |
| modelservice.vllm | vLLM container options | object | `{"extraArgs":[],"extraEnvVars":[],"image":{"imagePullPolicy":"IfNotPresent","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d","tag":"0.0.8"},"loadFormat":"","logLevel":"INFO"}` |
| modelservice.vllm.extraArgs | Additional command line arguments for vLLM | list | `[]` |
| modelservice.vllm.extraEnvVars | Additional environment variables for vLLM containers | list | `[]` |
| modelservice.vllm.loadFormat | Load format for model loading | string | `""` |
| modelservice.vllm.logLevel | Log level for vLLM | string | `"INFO"` |
| nameOverride | String to partially override common.names.fullname | string | `""` |
| redis | Bitnami/Redis chart configuration for caching | object | `{"enabled":true,"master":{"persistence":{"enabled":true,"size":"8Gi"}}}` |
| sampleApplication | Sample application deploying a model | object | `{"decode":{"extraArgs":[],"replicas":1},"enabled":true,"model":{"auth":{"hfToken":{"key":"HF_TOKEN","name":"llm-d-hf-token"}},"modelArtifactURI":"hf://meta-llama/Llama-3.2-3B-Instruct","modelName":"meta-llama/Llama-3.2-3B-Instruct"},"prefill":{"extraArgs":[],"replicas":1},"resources":{"limits":{"nvidia.com/gpu":"1"},"requests":{"nvidia.com/gpu":"1"}}}` |
| sampleApplication.decode | Decode configuration | object | `{"extraArgs":[],"replicas":1}` |
| sampleApplication.enabled | Enable rendering of sample application resources | bool | `true` |
| sampleApplication.model | Model configuration | object | `{"auth":{"hfToken":{"key":"HF_TOKEN","name":"llm-d-hf-token"}},"modelArtifactURI":"hf://meta-llama/Llama-3.2-3B-Instruct","modelName":"meta-llama/Llama-3.2-3B-Instruct"}` |
| sampleApplication.model.auth | HF token authentication | object | `{"hfToken":{"key":"HF_TOKEN","name":"llm-d-hf-token"}}` |
| sampleApplication.model.modelArtifactURI | Fully qualified model artifact location URI | string | `"hf://meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.model.modelName | Name of the model | string | `"meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.prefill | Prefill configuration | object | `{"extraArgs":[],"replicas":1}` |
| sampleApplication.resources | Resource requirements | object | `{"limits":{"nvidia.com/gpu":"1"},"requests":{"nvidia.com/gpu":"1"}}` |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
