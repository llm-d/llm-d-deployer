
# llm-d Helm Chart for OpenShift

![Version: 0.7.0](https://img.shields.io/badge/Version-0.7.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A Helm chart for llm-d

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Red Hat |  | <https://github.com/neuralmagic/llm-d-deployer> |

## Source Code

* <https://github.com/neuralmagic/llm-d-deployer>

---

## TL;DR

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add neuralmagic https://neuralmagic.github.io/llm-d-deployer

helm install my-llm-d neuralmagic/llm-d
```

## Prerequisites

- Git (v2.25 or [latest](https://github.com/git-guides/install-git#install-git-on-linux), for sparse-checkout support)
- Kubectl (1.25+ or [latest](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) with built-in kustomize support)

```shell
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

- Kubernetes 1.25+ (OpenShift 4.12+)
- Helm 3.10+ or [latest release](https://github.com/helm/helm/releases)

## Usage

Charts are available in the following formats:

- [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
- [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Installing from the Chart Repository

The following command can be used to add the chart repository:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add neuralmagic https://neuralmagic.github.io/llm-d-deployer
```

Once the chart has been added, install this chart. However before doing so, please review the default `values.yaml` and adjust as needed.

```console
helm upgrade -i <release_name> neuralmagic/llm-d
```

### Installing from an OCI Registry

Charts are also available in OCI format. The list of available releases can be found [here](https://github.com/orgs/neuralmagic/packages/container/package/llm-d-deployer%2Fllm-d).

Install one of the available versions:

```shell
helm upgrade -i <release_name> oci://ghcr.io/neuralmagic/llm-d-deployer/llm-d --version=<version>
```

> **Tip**: List all releases using `helm list`

### Testing a Release

Once an Helm Release has been deployed, you can test it using the [`helm test`](https://helm.sh/docs/helm/helm_test/) command:

```sh
helm test <release_name>
```

This will run a simple Pod in the cluster to check that the application deployed is up and running.

You can control whether to disable this test pod or you can also customize the image it leverages.
See the `test.enabled` and `test.image` parameters in the [`values.yaml`](./values.yaml) file.

> **Tip**: Disabling the test pod will not prevent the `helm test` command from passing later on. It will simply report that no test suite is available.

Below are a few examples:

<details>

<summary>Disabling the test pod</summary>

```sh
helm install <release_name> <repo_or_oci_registry> \
  --set test.enabled=false
```

</details>

<details>

<summary>Customizing the test pod image</summary>

```sh
helm install <release_name> <repo_or_oci_registry> \
  --set test.image.repository=curl/curl-base \
  --set test.image.tag=8.11.1
```

</details>

### Uninstalling the Chart

To uninstall/delete the `my-llm-d-release` deployment:

```console
helm uninstall my-llm-d-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Requirements

Kubernetes: `>= 1.25.0-0`

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
| gateway | Gateway configuration | object | See below |
| gateway.annotations | Additional annotations provided to the Gateway resource | object | `{}` |
| gateway.enabled | Deploy resources related to Gateway | bool | `true` |
| gateway.fullnameOverride | String to fully override gateway.fullname | string | `""` |
| gateway.gatewayClassName | Gateway class that determines the backend used Currently supported values: "kgateway" or "istio" | string | `"kgateway"` |
| gateway.nameOverride | String to partially override gateway.fullname | string | `""` |
| gateway.serviceType | Gateway's service type. Ingress is only available if the service type is set to NodePort. Accepted values: ["LoadBalancer", "NodePort"] | string | `"NodePort"` |
| global | Global parameters Global Docker image parameters Please, note that this will override the image parameters, including dependencies, configured to use the global value Current available global Docker image parameters: imageRegistry, imagePullSecrets and storageClass | object | See below |
| global.imagePullSecrets | Global Docker registry secret names as an array </br> E.g. `imagePullSecrets: [myRegistryKeySecretName]` | list | `[]` |
| global.imageRegistry | Global Docker image registry | string | `""` |
| ingress | Ingress configuration | object | See below |
| ingress.annotations | Additional annotations for the Ingress resource | object | `{}` |
| ingress.enabled | Deploy Ingress | bool | `true` |
| ingress.extraHosts | List of additional hostnames to be covered with this ingress record (e.g. a CNAME) <!-- E.g. extraHosts:   - name: llm-d.env.example.com     path: / (Optional)     pathType: Prefix (Optional)     port: 7007 (Optional) --> | list | `[]` |
| ingress.extraTls | The TLS configuration for additional hostnames to be covered with this ingress record. <br /> Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls <!-- E.g. extraTls:   - hosts:     - llm-d.env.example.com     secretName: llm-d-env --> | list | `[]` |
| ingress.host | Hostname to be used to expose the NodePort service to the inferencing gateway | string | `""` |
| ingress.ingressClassName | Name of the IngressClass cluster resource which defines which controller will implement the resource (e.g nginx) | string | `""` |
| ingress.path | Path to be used to expose the full route to access the inferencing gateway | string | `"/"` |
| ingress.tls | Ingress TLS parameters | object | `{"enabled":false,"secretName":""}` |
| ingress.tls.enabled | Enable TLS configuration for the host defined at `ingress.host` parameter | bool | `false` |
| ingress.tls.secretName | The name to which the TLS Secret will be called | string | `""` |
| kubeVersion | Override Kubernetes version | string | `""` |
| modelservice | Model service controller configuration | object | See below |
| modelservice.annotations | Annotations to add to all modelservice resources | object | `{}` |
| modelservice.decode | Decode options | object | See below |
| modelservice.decode.tolerations | Tolerations configuration to deploy decode pods to tainted nodes | list | See below |
| modelservice.decode.tolerations[0] | default NVIDIA GPU toleration | object | `{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}` |
| modelservice.enabled | Toggle to deploy modelservice controller related resources | bool | `true` |
| modelservice.epp | Endpoint picker configuration | object | See below |
| modelservice.epp.defaultEnvVars | Default environment variables for endpoint picker, use `extraEnvVars` to override default behavior by defining the same variable again. Ref: https://github.com/neuralmagic/gateway-api-inference-extension/tree/dev?tab=readme-ov-file#temporary-fork-configuration | list | `[{"name":"ENABLE_KVCACHE_AWARE_SCORER","value":"{{ .Values.redis.enabled }}"},{"name":"KVCACHE_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"KVCACHE_INDEXER_REDIS_ADDR","value":"{{ if .Values.redis.enabled }}{{ include \"redis.master.service.fullurl\" . }}{{ end }}"},{"name":"ENABLE_PREFIX_AWARE_SCORER","value":"true"},{"name":"PREFIX_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"ENABLE_LOAD_AWARE_SCORER","value":"true"},{"name":"LOAD_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"ENABLE_SESSION_AWARE_SCORER","value":"true"},{"name":"SESSION_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"PD_ENABLED","value":"true"},{"name":"PD_PROMPT_LEN_THRESHOLD","value":"10"},{"name":"PREFILL_ENABLE_KVCACHE_AWARE_SCORER","value":"true"},{"name":"PREFILL_KVCACHE_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"PREFILL_ENABLE_LOAD_AWARE_SCORER","value":"true"},{"name":"PREFILL_LOAD_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"PREFILL_ENABLE_PREFIX_AWARE_SCORER","value":"true"},{"name":"PREFILL_PREFIX_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"DECODE_ENABLE_KVCACHE_AWARE_SCORER","value":"true"},{"name":"DECODE_KVCACHE_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"DECODE_ENABLE_LOAD_AWARE_SCORER","value":"true"},{"name":"DECODE_LOAD_AWARE_SCORER_WEIGHT","value":"1.0"},{"name":"DECODE_ENABLE_PREFIX_AWARE_SCORER","value":"true"},{"name":"DECODE_PREFIX_AWARE_SCORER_WEIGHT","value":"1.0"}]` |
| modelservice.epp.extraEnvVars | Additional environment variables for endpoint picker | list | `[]` |
| modelservice.epp.image | Endpoint picker image used in ModelService CR presets | object | `{"imagePullPolicy":"Always","registry":"quay.io","repository":"llm-d/llm-d-gateway-api-inference-extension-dev","tag":"0.0.5"}` |
| modelservice.epp.metrics.enabled | Enable metrics scraping from endpoint picker service, see `modelservice.serviceMonitor` for configuration | bool | `true` |
| modelservice.fullnameOverride | String to fully override modelservice.fullname | string | `""` |
| modelservice.image | Modelservice controller image, please change only if appropriate adjustments to the CRD are being made | object | `{"imagePullPolicy":"Always","registry":"quay.io","repository":"llm-d/llm-d-model-service","tag":"0.0.8"}` |
| modelservice.metrics | Enable metrics gathering via podMonitor / ServiceMonitor | object | `{"enabled":true}` |
| modelservice.nameOverride | String to partially override modelservice.fullname | string | `""` |
| modelservice.podAnnotations | Pod annotations for modelservice | object | `{}` |
| modelservice.podLabels | Pod labels for modelservice | object | `{}` |
| modelservice.prefill | Prefill options | object | See below |
| modelservice.prefill.tolerations | Tolerations configuration to deploy prefill pods to tainted nodes | list | See below |
| modelservice.prefill.tolerations[0] | default NVIDIA GPU toleration | object | `{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}` |
| modelservice.rbac.create | Enable the creation of RBAC resources | bool | `true` |
| modelservice.replicas | Number of controller replicas | int | `1` |
| modelservice.routingProxy | Routing proxy container options | object | See below |
| modelservice.routingProxy.image | Routing proxy image used in ModelService CR presets | object | `{"imagePullPolicy":"Always","registry":"quay.io","repository":"llm-d/llm-d-routing-sidecar","tag":"0.0.5"}` |
| modelservice.service.enabled | Toggle to deploy a Service resource for Model service controller | bool | `true` |
| modelservice.service.port | Port number exposed from Model Service controller | int | `8443` |
| modelservice.service.type | Service type | string | `"ClusterIP"` |
| modelservice.serviceAccount | Service Account Configuration | object | See below |
| modelservice.serviceAccount.annotations | Additional custom annotations for the ServiceAccount. | object | `{}` |
| modelservice.serviceAccount.create | Enable the creation of a ServiceAccount for Modelservice pods | bool | `true` |
| modelservice.serviceAccount.fullnameOverride | String to fully override modelservice.serviceAccountName, defaults to modelservice.fullname | string | `""` |
| modelservice.serviceAccount.labels | Additional custom labels to the service ServiceAccount. | object | `{}` |
| modelservice.serviceAccount.nameOverride | String to partially override modelservice.serviceAccountName, defaults to modelservice.fullname | string | `""` |
| modelservice.serviceMonitor | Prometheus ServiceMonitor configuration <br /> Ref: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api-reference/api.md | object | See below |
| modelservice.serviceMonitor.annotations | Additional annotations provided to the ServiceMonitor | object | `{}` |
| modelservice.serviceMonitor.interval | ServiceMonitor endpoint interval at which metrics should be scraped | string | `"15s"` |
| modelservice.serviceMonitor.labels | Additional labels provided to the ServiceMonitor | object | `{}` |
| modelservice.serviceMonitor.namespaceSelector | ServiceMonitor namespace selector | object | `{"any":false,"matchNames":[]}` |
| modelservice.serviceMonitor.path | ServiceMonitor endpoint path | string | `"/metrics"` |
| modelservice.serviceMonitor.port | ServiceMonitor endpoint port | string | `"vllm"` |
| modelservice.serviceMonitor.selector | ServiceMonitor selector matchLabels </br> matchLabels must match labels on modelservice Services | object | `{"matchLabels":{}}` |
| modelservice.vllm | vLLM container options | object | See below |
| modelservice.vllm.image | vLLM image used in ModelService CR presets | object | `{"imagePullPolicy":"Always","registry":"quay.io","repository":"llm-d/llm-d-dev","tag":"vllm-nixl-0.0.6"}` |
| modelservice.vllm.metrics.enabled | Enable metrics scraping from vllm service, see `modelservice.serviceMonitor` for configuration | bool | `true` |
| modelservice.vllmSim | vLL sim container options | object | See below |
| modelservice.vllmSim.image | vLLM sim image used in ModelService CR presets | object | `{"imagePullPolicy":"IfNotPresent","registry":"quay.io","repository":"llm-d/vllm-sim","tag":"0.0.4"}` |
| nameOverride | String to partially override common.names.fullname | string | `""` |
| redis | Bitnami/Redis chart configuration | object | Use sane defaults for minimal Redis deployment |
| sampleApplication | Sample application deploying a p-d pair of specific model | object | See below |
| sampleApplication.downloadModelJob.hfModelID | If `.Values.sampleApplication.model.modelArtifactURI` starts with `pvc://` what huggingface repo to load onto the pvc | string | `"meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.enabled | Enable rendering of sample application resources | bool | `true` |
| sampleApplication.inferencePoolPort | InferencePool port configuration | int | `8000` |
| sampleApplication.model.auth.hfToken | HF token auth config via k8s secret. Required if using hf:// URI or using pvc:// URI with `--download-model` in quickstart | object | `{"create":true,"key":"HF_TOKEN","name":"llm-d-hf-token"}` |
| sampleApplication.model.auth.hfToken.create | If the secret should be created or one already exists | bool | `true` |
| sampleApplication.model.auth.hfToken.key | Value of the token. Do not set this but use `envsubst` in conjunction with the helm chart | string | `"HF_TOKEN"` |
| sampleApplication.model.auth.hfToken.name | Name of the secret to create to store your huggingface token | string | `"llm-d-hf-token"` |
| sampleApplication.model.modelArtifactURI | Fully qualified pvc URI: pvc://<pvc-name>/<model-path> | string | `"pvc://llama-3.2-3b-instruct-pvc/models/meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.model.modelName | Name of the model | string | `"Llama-3.2-3B-Instruct"` |
| sampleApplication.model.servedModelNames | Aliases to the Model named vllm will serve with | list | `[]` |
| sampleApplication.resources | Resource requests/limits <br /> Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-requests-and-limits-of-pod-and-container | object | `{"limits":{"nvidia.com/gpu":1},"requests":{"nvidia.com/gpu":1}}` |
| test | Helm tests | object | `{"enabled":false}` |
| test.enabled | Enable rendering of helm test resources | bool | `false` |

## Features

TBD
