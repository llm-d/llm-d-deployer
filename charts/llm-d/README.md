
# llm-d Helm Chart

![Version: 1.0.21](https://img.shields.io/badge/Version-1.0.21-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

llm-d is a Kubernetes-native high-performance distributed LLM inference framework

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| llm-d |  | <https://github.com/llm-d/llm-d-deployer> |

## Source Code

* <https://github.com/llm-d/llm-d-deployer>

---

## TL;DR

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d https://llm-d.ai/llm-d-deployer

helm install my-llm-d llm-d/llm-d
```

## Prerequisites

- Git (v2.25 or [latest](https://github.com/git-guides/install-git#install-git-on-linux), for sparse-checkout support)
- Kubectl (1.25+ or [latest](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) with built-in kustomize support)

```shell
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

- Kubernetes 1.30+ (OpenShift 4.17+)
- Helm 3.10+ or [latest release](https://github.com/helm/helm/releases)
- [Gateway API](https://gateway-api.sigs.k8s.io/guides/) (see for [examples](https://github.com/llm-d/llm-d-deployer/blob/6db03770626f6e67b099300c66bfa535b2504727/chart-dependencies/ci-deps.sh#L22) we use in our CI)
- [kGateway](https://kgateway.dev/) (or [Istio](http://istio.io/)) installed in the cluster (see for [examples](https://github.com/llm-d/llm-d-deployer/blob/6db03770626f6e67b099300c66bfa535b2504727/chart-dependencies/kgateway/install.sh) we use in our CI)

## Usage

Charts are available in the following formats:

- [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
- [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Installing from the Chart Repository

The following command can be used to add the chart repository:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d https://llm-d.ai/llm-d-deployer
```

Once the chart has been added, install this chart. However before doing so, please review the default `values.yaml` and adjust as needed.

```console
helm upgrade -i <release_name> llm-d/llm-d
```

### Installing from an OCI Registry

Charts are also available in OCI format. The list of available releases can be found [here](https://github.com/orgs/llm-d/packages/container/package/llm-d-deployer%2Fllm-d).

Install one of the available versions:

```shell
helm upgrade -i <release_name> oci://ghcr.io/llm-d/llm-d-deployer/llm-d --version=<version>
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

Kubernetes: `>= 1.30.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | common | 2.27.0 |
| https://charts.bitnami.com/bitnami | redis | 20.13.4 |

## Values

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| clusterDomain | Default Kubernetes cluster domain | string | `"cluster.local"` |
| common | Parameters for bitnami.common dependency | object | `{}` |
| commonAnnotations | Annotations to add to all deployed objects | object | `{}` |
| commonLabels | Labels to add to all deployed objects | object | `{}` |
| extraDeploy | Array of extra objects to deploy with the release | list | `[]` |
| fullnameOverride | String to fully override common.names.fullname | string | `""` |
| gateway | Gateway configuration | object | See below |
| gateway.annotations | Additional annotations provided to the Gateway resource | object | `{}` |
| gateway.enabled | Deploy resources related to Gateway | bool | `true` |
| gateway.fullnameOverride | String to fully override gateway.fullname | string | `""` |
| gateway.gatewayClassName | Gateway class that determines the backend used Currently supported values: "kgateway" or "istio" | string | `"istio"` |
| gateway.nameOverride | String to partially override gateway.fullname | string | `""` |
| gateway.serviceType | Gateway's service type. Ingress is only available if the service type is set to NodePort. Accepted values: ["LoadBalancer", "NodePort"] | string | `"NodePort"` |
| global | Global parameters Global Docker image parameters Please, note that this will override the image parameters, including dependencies, configured to use the global value Current available global Docker image parameters: imageRegistry, imagePullSecrets and storageClass | object | See below |
| global.imagePullSecrets | Global Docker registry secret names as an array </br> E.g. `imagePullSecrets: [myRegistryKeySecretName]` | list | `[]` |
| global.imageRegistry | Global Docker image registry | string | `""` |
| ingress | Ingress configuration | object | See below |
| ingress.annotations | Additional annotations for the Ingress resource | object | `{}` |
| ingress.clusterRouterBase | used as part of the host dirivation if not specified from OCP cluster domain (dont edit) | string | `""` |
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
| modelservice.affinity | Affinity for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity | object | `{}` |
| modelservice.annotations | Annotations to add to all modelservice resources | object | `{}` |
| modelservice.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.decode | Decode options | object | See below |
| modelservice.decode.affinity | Affinity for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity | object | `{}` |
| modelservice.decode.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.decode.nodeSelector | Node labels for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector | object | `{}` |
| modelservice.decode.podSecurityContext | Security settings for a Pod.  The security settings that you specify for a Pod apply to all Containers in the Pod. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod | object | `{}` |
| modelservice.decode.tolerations | Node tolerations for server scheduling to nodes with taints <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | list | `[{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}]` |
| modelservice.decode.tolerations[0] | default NVIDIA GPU toleration | object | `{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}` |
| modelservice.decode.topologySpreadConstraints | Topology Spread Constraints for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints | list | `[]` |
| modelservice.decode.vllm | vLLM container settings | object | `{"containerSecurityContext":{"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["MKNOD"]}}}}` |
| modelservice.decode.vllm.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["MKNOD"]}}}` |
| modelservice.enabled | Toggle to deploy modelservice controller related resources | bool | `true` |
| modelservice.epp | Endpoint picker configuration | object | See below |
| modelservice.epp.affinity | Affinity for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity | object | `{}` |
| modelservice.epp.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.epp.defaultEnvVars | Default environment variables for endpoint picker, use `defaultEnvVarsOverride` to override default behavior by defining the same variable again. Ref: https://github.com/llm-d/llm-d-inference-scheduler/blob/main/docs/architecture.md#scorers--configuration | list | `[{"name":"ENABLE_KVCACHE_AWARE_SCORER","value":"false"},{"name":"KVCACHE_AWARE_SCORER_WEIGHT","value":"1"},{"name":"KVCACHE_INDEXER_REDIS_ADDR","value":"{{ if .Values.redis.enabled }}{{ include \"redis.master.service.fullurl\" . }}{{ end }}"},{"name":"ENABLE_PREFIX_AWARE_SCORER","value":"true"},{"name":"PREFIX_AWARE_SCORER_WEIGHT","value":"2"},{"name":"ENABLE_LOAD_AWARE_SCORER","value":"true"},{"name":"LOAD_AWARE_SCORER_WEIGHT","value":"1"},{"name":"ENABLE_SESSION_AWARE_SCORER","value":"false"},{"name":"SESSION_AWARE_SCORER_WEIGHT","value":"1"},{"name":"PD_ENABLED","value":"false"},{"name":"PD_PROMPT_LEN_THRESHOLD","value":"10"},{"name":"PREFILL_ENABLE_KVCACHE_AWARE_SCORER","value":"false"},{"name":"PREFILL_KVCACHE_AWARE_SCORER_WEIGHT","value":"1"},{"name":"PREFILL_KVCACHE_INDEXER_REDIS_ADDR","value":"{{ if .Values.redis.enabled }}{{ include \"redis.master.service.fullurl\" . }}{{ end }}"},{"name":"PREFILL_ENABLE_LOAD_AWARE_SCORER","value":"false"},{"name":"PREFILL_LOAD_AWARE_SCORER_WEIGHT","value":"1"},{"name":"PREFILL_ENABLE_PREFIX_AWARE_SCORER","value":"false"},{"name":"PREFILL_PREFIX_AWARE_SCORER_WEIGHT","value":"1"},{"name":"PREFILL_ENABLE_SESSION_AWARE_SCORER","value":"false"},{"name":"PREFILL_SESSION_AWARE_SCORER_WEIGHT","value":"1"}]` |
| modelservice.epp.defaultEnvVarsOverride | Override default environment variables for endpoint picker. This list has priorito over `defaultEnvVars` | list | `[]` |
| modelservice.epp.image | Endpoint picker image used in ModelService CR presets | object | See below |
| modelservice.epp.image.imagePullPolicy | Specify a imagePullPolicy | string | `"Always"` |
| modelservice.epp.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| modelservice.epp.image.registry | Endpoint picker image registry | string | `"ghcr.io"` |
| modelservice.epp.image.repository | Endpoint picker image repository | string | `"llm-d/llm-d-inference-scheduler"` |
| modelservice.epp.image.tag | Endpoint picker image tag | string | `"0.0.4"` |
| modelservice.epp.metrics | Enable metrics gathering via podMonitor / ServiceMonitor | object | `{"enabled":true,"serviceMonitor":{"annotations":{},"interval":"10s","labels":{},"namespaceSelector":{"any":false,"matchNames":[]},"path":"/metrics","port":"metrics","selector":{"matchLabels":{}}}}` |
| modelservice.epp.metrics.enabled | Enable metrics scraping from endpoint picker service | bool | `true` |
| modelservice.epp.metrics.serviceMonitor | Prometheus ServiceMonitor configuration <br /> Ref: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api-reference/api.md | object | See below |
| modelservice.epp.metrics.serviceMonitor.annotations | Additional annotations provided to the ServiceMonitor | object | `{}` |
| modelservice.epp.metrics.serviceMonitor.interval | ServiceMonitor endpoint interval at which metrics should be scraped | string | `"10s"` |
| modelservice.epp.metrics.serviceMonitor.labels | Additional labels provided to the ServiceMonitor | object | `{}` |
| modelservice.epp.metrics.serviceMonitor.namespaceSelector | ServiceMonitor namespace selector | object | `{"any":false,"matchNames":[]}` |
| modelservice.epp.metrics.serviceMonitor.path | ServiceMonitor endpoint path | string | `"/metrics"` |
| modelservice.epp.metrics.serviceMonitor.port | ServiceMonitor endpoint port | string | `"metrics"` |
| modelservice.epp.metrics.serviceMonitor.selector | ServiceMonitor selector matchLabels </br> matchLabels must match labels on modelservice Services | object | `{"matchLabels":{}}` |
| modelservice.epp.nodeSelector | Node labels for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector | object | `{}` |
| modelservice.epp.podSecurityContext | Security settings for a Pod.  The security settings that you specify for a Pod apply to all Containers in the Pod. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod | object | `{}` |
| modelservice.epp.tolerations | Node tolerations for server scheduling to nodes with taints <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | list | `[]` |
| modelservice.epp.topologySpreadConstraints | Topology Spread Constraints for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints | list | `[]` |
| modelservice.fullnameOverride | String to fully override modelservice.fullname | string | `""` |
| modelservice.image | Modelservice controller image, please change only if appropriate adjustments to the CRD are being made | object | See below |
| modelservice.image.imagePullPolicy | Specify a imagePullPolicy | string | `"Always"` |
| modelservice.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| modelservice.image.registry | Model Service controller image registry | string | `"ghcr.io"` |
| modelservice.image.repository | Model Service controller image repository | string | `"llm-d/llm-d-model-service"` |
| modelservice.image.tag | Model Service controller image tag | string | `"0.0.10"` |
| modelservice.inferenceSimulator | llm-d inference simulator container options | object | See below |
| modelservice.inferenceSimulator.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.inferenceSimulator.image | llm-d inference simulator image used in ModelService CR presets | object | See below |
| modelservice.inferenceSimulator.image.imagePullPolicy | Specify a imagePullPolicy | string | `"IfNotPresent"` |
| modelservice.inferenceSimulator.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| modelservice.inferenceSimulator.image.registry | llm-d inference simulator image registry | string | `"ghcr.io"` |
| modelservice.inferenceSimulator.image.repository | llm-d inference simulator image repository | string | `"llm-d/llm-d-inference-sim"` |
| modelservice.inferenceSimulator.image.tag | llm-d inference simulator image tag | string | `"0.0.4"` |
| modelservice.metrics | Enable metrics gathering via podMonitor / ServiceMonitor | object | `{"enabled":true,"serviceMonitor":{"annotations":{},"interval":"15s","labels":{},"namespaceSelector":{"any":false,"matchNames":[]},"path":"/metrics","port":"vllm","selector":{"matchLabels":{}}}}` |
| modelservice.metrics.enabled | Enable metrics scraping from prefill and decode services, see `model | bool | `true` |
| modelservice.metrics.serviceMonitor | Prometheus ServiceMonitor configuration <br /> Ref: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api-reference/api.md | object | See below |
| modelservice.metrics.serviceMonitor.annotations | Additional annotations provided to the ServiceMonitor | object | `{}` |
| modelservice.metrics.serviceMonitor.interval | ServiceMonitor endpoint interval at which metrics should be scraped | string | `"15s"` |
| modelservice.metrics.serviceMonitor.labels | Additional labels provided to the ServiceMonitor | object | `{}` |
| modelservice.metrics.serviceMonitor.namespaceSelector | ServiceMonitor namespace selector | object | `{"any":false,"matchNames":[]}` |
| modelservice.metrics.serviceMonitor.path | ServiceMonitor endpoint path | string | `"/metrics"` |
| modelservice.metrics.serviceMonitor.port | ServiceMonitor endpoint port | string | `"vllm"` |
| modelservice.metrics.serviceMonitor.selector | ServiceMonitor selector matchLabels </br> matchLabels must match labels on modelservice Services | object | `{"matchLabels":{}}` |
| modelservice.nameOverride | String to partially override modelservice.fullname | string | `""` |
| modelservice.nodeSelector | Node labels for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector | object | `{}` |
| modelservice.podAnnotations | Pod annotations for modelservice | object | `{}` |
| modelservice.podLabels | Pod labels for modelservice | object | `{}` |
| modelservice.podSecurityContext | Security settings for a Pod.  The security settings that you specify for a Pod apply to all Containers in the Pod. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod | object | `{}` |
| modelservice.prefill | Prefill options | object | See below |
| modelservice.prefill.affinity | Affinity for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity | object | `{}` |
| modelservice.prefill.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.prefill.nodeSelector | Node labels for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector | object | `{}` |
| modelservice.prefill.podSecurityContext | Security settings for a Pod.  The security settings that you specify for a Pod apply to all Containers in the Pod. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod | object | `{}` |
| modelservice.prefill.tolerations | Node tolerations for server scheduling to nodes with taints <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | list | `[{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}]` |
| modelservice.prefill.tolerations[0] | default NVIDIA GPU toleration | object | `{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}` |
| modelservice.prefill.topologySpreadConstraints | Topology Spread Constraints for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints | list | `[]` |
| modelservice.prefill.vllm | vLLM container settings | object | `{"containerSecurityContext":{"allowPrivilegeEscalation":false}}` |
| modelservice.prefill.vllm.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{"allowPrivilegeEscalation":false}` |
| modelservice.rbac.create | Enable the creation of RBAC resources | bool | `true` |
| modelservice.replicas | Number of controller replicas | int | `1` |
| modelservice.routingProxy | Routing proxy container options | object | See below |
| modelservice.routingProxy.containerSecurityContext | Security settings for a Container. <br /> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container | object | `{}` |
| modelservice.routingProxy.image | Routing proxy image used in ModelService CR presets | object | `{"imagePullPolicy":"IfNotPresent","pullSecrets":[],"registry":"ghcr.io","repository":"llm-d/llm-d-routing-sidecar","tag":"0.0.6"}` |
| modelservice.routingProxy.image.imagePullPolicy | Specify a imagePullPolicy | string | `"IfNotPresent"` |
| modelservice.routingProxy.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| modelservice.routingProxy.image.registry | Routing proxy image registry | string | `"ghcr.io"` |
| modelservice.routingProxy.image.repository | Routing proxy image repository | string | `"llm-d/llm-d-routing-sidecar"` |
| modelservice.routingProxy.image.tag | Routing proxy image tag | string | `"0.0.6"` |
| modelservice.service.enabled | Toggle to deploy a Service resource for Model service controller | bool | `true` |
| modelservice.service.port | Port number exposed from Model Service controller | int | `8443` |
| modelservice.service.type | Service type | string | `"ClusterIP"` |
| modelservice.serviceAccount | Service Account Configuration | object | See below |
| modelservice.serviceAccount.annotations | Additional custom annotations for the ServiceAccount. | object | `{}` |
| modelservice.serviceAccount.create | Enable the creation of a ServiceAccount for Modelservice pods | bool | `true` |
| modelservice.serviceAccount.fullnameOverride | String to fully override modelservice.serviceAccountName, defaults to modelservice.fullname | string | `""` |
| modelservice.serviceAccount.labels | Additional custom labels to the service ServiceAccount. | object | `{}` |
| modelservice.serviceAccount.nameOverride | String to partially override modelservice.serviceAccountName, defaults to modelservice.fullname | string | `""` |
| modelservice.tolerations | Node tolerations for server scheduling to nodes with taints <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | list | `[]` |
| modelservice.topologySpreadConstraints | Topology Spread Constraints for pod assignment <br /> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints | list | `[]` |
| modelservice.vllm | vLLM container options | object | See below |
| modelservice.vllm.image | vLLM image used in ModelService CR presets | object | See below |
| modelservice.vllm.image.imagePullPolicy | Specify a imagePullPolicy | string | `"IfNotPresent"` |
| modelservice.vllm.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| modelservice.vllm.image.registry | llm-d image registry | string | `"ghcr.io"` |
| modelservice.vllm.image.repository | llm-d image repository | string | `"llm-d/llm-d"` |
| modelservice.vllm.image.tag | llm-d image tag | string | `"0.0.8"` |
| modelservice.vllm.logLevel | Log level to run VLLM with <br /> VLLM supports standard python log-levels, see: https://docs.python.org/3/library/logging.html#logging-levels <br /> Options: "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL" | string | `"INFO"` |
| modelservice.vllm.metrics | Enable metrics gathering via podMonitor / ServiceMonitor | object | `{"enabled":true}` |
| modelservice.vllm.metrics.enabled | Enable metrics scraping from prefill & decode services | bool | `true` |
| nameOverride | String to partially override common.names.fullname | string | `""` |
| redis | Bitnami/Redis chart configuration | object | Use sane defaults for minimal Redis deployment |
| sampleApplication | Sample application deploying a p-d pair of specific model | object | See below |
| sampleApplication.baseConfigMapRefName | Name of the base configMapRef to use <br /> For the available presets see: `templates/modelservice/presets/` | string | `"basic-gpu-with-nixl-and-redis-lookup-preset"` |
| sampleApplication.decode.env | environment variables injected into each decode vLLM container | list | `[]` |
| sampleApplication.decode.extraArgs | args to add to the decode deployment | list | `[]` |
| sampleApplication.decode.replicas | number of desired decode replicas | int | `1` |
| sampleApplication.enabled | Enable rendering of sample application resources | bool | `true` |
| sampleApplication.endpointPicker.env | Apply additional env variables to the endpoint picker deployment <br /> Ref: https://github.com/neuralmagic/llm-d-inference-scheduler/blob/0.0.2/docs/architecture.md | list | `[]` |
| sampleApplication.inferencePoolPort | InferencePool port configuration | int | `8000` |
| sampleApplication.model.auth.hfToken | HF token auth config via k8s secret. | object | `{"key":"HF_TOKEN","name":"llm-d-hf-token"}` |
| sampleApplication.model.auth.hfToken.key | Key within the secret under which the token is located | string | `"HF_TOKEN"` |
| sampleApplication.model.auth.hfToken.name | Name of the secret to create to store your huggingface token | string | `"llm-d-hf-token"` |
| sampleApplication.model.modelArtifactURI | Fully qualified model artifact location URI <br /> For Hugging Face models use: `hf://<organization>/<repo>` <br /> For models located on PVC use: `pvc://<pvc_name>/<path_to_model>` | string | `"hf://meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.model.modelName | Name of the model | string | `"meta-llama/Llama-3.2-3B-Instruct"` |
| sampleApplication.model.servedModelNames | Aliases to the Model named vllm will serve with | list | `[]` |
| sampleApplication.prefill.env | environment variables injected into each decode vLLM container | list | `[]` |
| sampleApplication.prefill.extraArgs | args to add to the prefill deployment | list | `[]` |
| sampleApplication.prefill.replicas | number of desired prefill replicas | int | `1` |
| sampleApplication.resources | Resource requests/limits <br /> Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-requests-and-limits-of-pod-and-container | object | `{"limits":{"nvidia.com/gpu":"1"},"requests":{"nvidia.com/gpu":"1"}}` |
| test | Helm tests | object | `{"enabled":false,"image":{"imagePullPolicy":"Always","pullSecrets":[],"registry":"quay.io","repository":"curl/curl","tag":"latest"}}` |
| test.enabled | Enable rendering of helm test resources | bool | `false` |
| test.image.imagePullPolicy | Specify a imagePullPolicy | string | `"Always"` |
| test.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| test.image.registry | Test connection pod image registry | string | `"quay.io"` |
| test.image.repository | Test connection pod image repository. Note that the image needs to have both the `sh` and `curl` binaries in it. | string | `"curl/curl"` |
| test.image.tag | Test connection pod image tag. Note that the image needs to have both the `sh` and `curl` binaries in it. | string | `"latest"` |

## Features

This chart deploys all infrastructure required to run the [llm-d](https://llm-d.ai/) project. It includes:

- A Gateway
- A `ModelService` CRD
- A [Model Service controller](https://github.com/llm-d/llm-d-model-service) with full RBAC support
- [Redis](https://github.com/bitnami/charts/tree/main/bitnami/redis) deployment for LMCache and smart routing
- Enabled monitoring and metrics scraping for llm-d components

Once deployed you can create `ModelService` CRs to deploy your models. The model service controller will take care of deploying the models and exposing them through the Gateway.

### Sample Application

By default the chart also deploys a sample application that deploys a Llama model. See `.Values.sampleApplication` in the `values.yaml` file for more details. If you wish to get rid of it, set `sampleApplication.enabled` to `false` in the `values.yaml` file:

```bash
helm upgrade -i <release_name> llm-d/llm-d \
  --set sampleApplication.enabled=false
```

### Metrics collection

There are various metrics exposed by the llm-d components. To enable/disable scraping of these metrics, look for `metrics.enabled` toggles in the `values.yaml` file. By default, all components have metrics enabled.

### Model Service

A new custom resource definition (CRD) called `ModelService` is created by the chart. This CRD is used to deploy models on the cluster. The model service controller will take care of deploying the models.

To see the full spec of the `ModelService` CRD, refer to the [ModelService CRD API reference](https://github.com/llm-d/llm-d-model-service/blob/main/docs/api_reference/out.asciidoc).

A basic example of a `ModelService` CR looks like this:

```yaml
apiVersion: llm-d.ai/v1alpha1
kind: ModelService
metadata:
  name: <name>
spec:
  decoupleScaling: false
  baseConfigMapRef:
    name: basic-gpu-with-nixl-and-redis-lookup-preset
  routing:
    modelName: <model_name>
  modelArtifacts:
    uri: pvc://<pvc_name>/<path_to_model>
  decode:
    replicas: 1
    containers:
    - name: "vllm"
      args:
      - "--model"
      - <model_name>
  prefill:
    replicas: 1
    containers:
    - name: "vllm"
      args:
      - "--model"
      - <model_name>
```

## Quickstart

If you want to get started quickly and experiment with llm-d, you can also take a look at the [Quickstart](https://github.com/llm-d/llm-d-deployer/blob/main/quickstart/README.md) we provide. It wraps this chart and deploys a full llm-d stack with all it's prerequisites a sample application.

## Contributing

We welcome contributions to this chart! If you have any suggestions or improvements, please feel free to open an issue or submit a pull request. Please read our [contributing guide](https://github.com/llm-d/llm-d-deployer/blob/main/CONTRIBUTING.md) on how to submit a pull request.
