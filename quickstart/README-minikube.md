# llm-d Quick Start

Getting Started with llm-d on Kubernetes.

## Overview

This guide will walk you through the steps to install and deploy llm-d on a Kubernetes cluster. llm-d consists of the following components:

- Gateway API Inference Extension (GIE) - This extension upgrades an ext-proc-capable proxy or gateway - such as Envoy Gateway, kGateway, or the GKE Gateway - to become an inference gateway - supporting inference platform teams self-hosting large language models on Kubernetes. This integration makes it easy to expose and control access to your local OpenAI-compatible chat completion endpoints to other workloads on or off cluster, or to integrate your self-hosted models alongside model-as-a-service providers in a higher level AI Gateway like LiteLLM, Solo AI Gateway, or Apigee.

  The inference gateway:
  - Improves the tail latency and throughput of LLM completion requests against Kubernetes-hosted model servers using an extendable request scheduling algorithm that is kv-cache and request cost aware, avoiding evictions or queueing as load increases
  - Provides Kubernetes-native declarative APIs to route client model names to use-case specific LoRA adapters and control incremental rollout of new adapter versions, A/B traffic splitting, and safe blue-green base model and model server upgrades
  - Adds end to end observability around service objective attainment
  - Ensures operational guardrails between different client model names, allowing a platform team to safely serve many different GenAI workloads on the same pool of shared foundation model servers for higher utilization and fewer required accelerators

- Distributed KV Cache
  - LMCache (in llm-d container)
  - NIXL (in llm-d container)
  - KVCache Indexer
  - Redis

- Model Service Controller - ModelService is a Kubernetes operator (CRD + controller) that enables the creation of vllm pods and routing resources for a given model.
  - Enables disaggregated prefill
  - Supports creation of Gateway API Inference Extension resources for routing
  - Supports auto-scaling with HPA
  - Supports independent scaling of prefill and decode instances
  - Supports independent node affinities for prefill and decode instances
  - Supports model loading from OCI images, HuggingFace public and private registries, and PVCs
- Metrics Service (Prometheus)

### Architecture

![llm-d Architecture](assets/arch.jpg)

### Required tools

Following prerequisite are required for the installer to work.

- [yq – installation & releases](https://github.com/mikefarah/yq#install)
- [jq – download & install guide](https://stedolan.github.io/jq/download/)
- [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [Kustomize – official install docs](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

You can use the installer script that installs all the required dependencies.

```bash
./install-deps.sh
```

### Required credentials and configuration

- [llm-d-deployer GitHub repo – clone here](https://github.com/neuralmagic/llm-d-deployer.git)
- [Quay.io Registry – sign-up & credentials](https://quay.io/)
- [Red Hat Registry – terms & access](https://access.redhat.com/registry/)
- [HuggingFace HF_TOKEN](https://huggingface.co/docs/hub/en/security-tokens)

Registry Authentication: The installer looks for an auth file in:

```bash
~/.config/containers/auth.json
# or
~/.config/containers/config.json
```

If not found, you can create one with the following commands:

Create with Docker:

```bash
docker --config ~/.config/containers/ login quay.io
```

Create with Podman:

```bash
podman login quay.io --authfile ~/.config/containers/auth.json
```

> ⚠️ You may need to visit Hugging Face [meta-llama/Llama-3.2-3B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct) and
> accept the usage terms to pull this with your HF token if you have not already done so.

### Target Platform

#### MiniKube

If you planned to deploy local minikube cluster, these dependencies need to be installed.

- [Minikube – getting-started guide](https://minikube.sigs.k8s.io/docs/start/)
- [Podman](https://podman.io/docs/installation) or [Docker](https://docs.docker.com/get-docker/)
- [CUDA Toolkit – downloads & docs](https://developer.nvidia.com/cuda-toolkit)
- [NVIDIA Container Toolkit – install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

For GPU support, see the Minikube documentation as there are a couple of commands that may need to be run [Using NVIDIA GPUs with minikube](https://minikube.sigs.k8s.io/docs/tutorials/nvidia/).

This can be run on a minimum ec2 node type [g6e.12xlarge](https://aws.amazon.com/ec2/instance-types/g6e/) (4xL40S 48GB but only 2 are used by default) to infer the model meta-llama/Llama-3.2-3B-Instruct that will get spun up.

> ⚠️ If your cluster has no available GPUs, the **prefill** and **decode** pods will remain in **Pending** state.

Verify you have properly installed the container toolkit with the runtime of your choice.

```yaml
# Podman
podman run --rm --security-opt=label=disable --device=nvidia.com/gpu=all ubuntu nvidia-smi
# Docker
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

To Provision a Minikube cluster run the `llmd-installer-minikube.sh` script.

```bash
./llmd-installer-minikube.sh --provision-minikube-gpu
```

## llm-d Installation

The llm-d-deployer contains all the helm charts necessary to deploy llm-d. To facilitate the installation of the helm charts, the `llmd-installer-minikube.sh` script is provided. This script will populate the necessary manifests in the `manifests` directory. After this, it will apply all the manifests in order to bring up the cluster.

Before proceeding with the installation, ensure you have installed the required dependencies

### Usage

The installer needs to be run from the `llm-d-deployer/quickstart` directory.

```bash
./llmd-installer-minikube.sh [OPTIONS]
```

### Flags

| Flag                           | Description                                                                                             | Example                                                   |
|--------------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `--hf-token TOKEN`             | HuggingFace API token (or set `HF_TOKEN` env var)                                                       | `./llmd-installer-minikube.sh --hf-token "abc123"`                        |
| `--auth-file PATH`             | Path to your registry auth file ig not in one of the two listed files in the auth section of the readme | `./llmd-installer-minikube.sh --auth-file ~/.config/containers/auth.json` |
| `--storage-size SIZE`          | Size of storage volume (default: 7Gi)                                                                   | `./llmd-installer-minikube.sh --storage-size 15Gi`                        |
| `--skip-download-model`        | Skip downloading the model to PVC if modelArtifactURI is pvc based                                      | `./llmd-installer.sh --skip-download-model`                      |
| `--storage-class CLASS`        | Storage class to use (default: standard)                                                                | `./llmd-installer-minikube.sh --storage-class standard`                  |
| `--namespace NAME`             | Kubernetes namespace to use (default: `llm-d`)                                                          | `./llmd-installer-minikube.sh --namespace foo`                            |
| `--values NAME`                | Absolute path to a Helm values.yaml file (default: llm-d-deployer/charts/llm-d/values.yaml)             | `./llmd-installer-minikube.sh --values /path/to/values.yaml`              |
| `--uninstall`                  | Uninstall llm-d and cleanup resources                                                                   | `./llmd-installer-minikube.sh --uninstall`                                |
| `--disable-metrics-collection` | Disable metrics collection (Prometheus will not be installed)                                       | `./llmd-installer-minikube.sh --disable-metrics-collection`               |
| `-h`, `--help`                 | Show help and exit                                                                                      | `./llmd-installer-minikube.sh --help`                                     |

## Examples

For additional information regarding Minikube support with GPUs see [Using NVIDIA GPUs with minikube](https://minikube.sigs.k8s.io/docs/tutorials/nvidia/).

### Provision Minikube cluster with GPU support and install llm-d

A hugging-face token is required either exported in your environment or passed via the `--hf-token` flag.

```bash
export HF_TOKEN="your-token"
./llmd-installer-minikube.sh --provision-minikube-gpu
```

### Install on an existing llm-d minikube cluster

- If you have already installed a minikube cluster and don't want to reinstall the cluster, simply rerun the installer
with no flags. Note: you should run `llmd-installer-minikube.sh --uninstall` prior to reinstalling to reset the cluster
to avoid any conflicts with existing deployments.

```bash
export HF_TOKEN="your-token"
./llmd-installer-minikube.sh
```

### Provision Minikube cluster without GPU support and install llm-d

**note**: prefill/decode pods will stay in pending status since there is no GPU node to schedule on. This scenario
would be for testing component functionality up until p/d pod deployments and would not require any GPUs on the host.

```bash
export HF_TOKEN="your-token"
./llmd-installer-minikube.sh --provision-minikube
```

### Manually minikube operations

If you prefer to start the minikube cluster manually simply run:

```bash
minikube start --driver docker --container-runtime docker --gpus all
```

## Model Service

### Customizing the ModelService

The ModelService looks like:

```yaml
kind: ModelService
metadata:
spec:
```

### Creating a New Model Service

To create a new model service, you can edit the ModelService custom resource for your needs. Examples have been included.

```bash
kubectl apply -f modelservice.yaml
```

### Validation

The inference-gateway serves as the HTTP ingress point for all inference requests in our deployment.
It’s implemented as a Kubernetes Gateway (`gateway.networking.k8s.io/v1`) using whichever `gatewayClassName` you’ve
chosen, either `kgateway` or `istio` and sits in front of your inference pods to handle path-based routing, load-balancing,
retries, and metrics. All calls to `/v1/models` and `/v1/completions` flow through this gateway to the appropriate
`decode` or `prefill` services.

```bash
# -------------------------------------------------------------------------
# Option A: Direct NodePort (no minikube tunnel required)
# -------------------------------------------------------------------------
# 1) Grab the Minikube VM IP and the NodePort that the gateway is listening on
MODEL_ID=Llama-3.2-3B-Instruct
MINIKUBE_IP=$(minikube ip)
NODEPORT=$(kubectl get svc llm-d-inference-gateway -n llm-d -o jsonpath='{.spec.ports[0].nodePort}')

# 2) Curl the same completion endpoint on that high-numbered port:
curl -X POST http://$MINIKUBE_IP:$NODEPORT/v1/completions \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'"$MODEL_ID"'",
    "prompt": "You are a helpful AI assistant. Please introduce yourself in one sentence."
  }'


# -------------------------------------------------------------------------
# Option B: LoadBalancer + minikube tunnel
# -------------------------------------------------------------------------
# 1) Before minkube tunnel is run: EXTERNAL-IP is still <pending>
kubectl get svc -n llm-d | grep llm-d-inference-gateway
# ➜ llm-d-inference-gateway LoadBalancer 10.109.40.169 <pending> 80:30185/TCP

# 2) In a separate terminal, start the tunnel (grants a host-reachable VIP)
minikube tunnel

# 3) After minikube tunnel is run: EXTERNAL-IP flips to the real address
kubectl get svc -n llm-d | grep llm-d-inference-gateway
# ➜ llm-d-inference-gateway LoadBalancer 10.109.40.169 10.109.40.169 80:30185/TCP

# 4) Hit the gateway’s plain completion endpoint with a role-based prompt:
MODEL_ID=Llama-3.2-3B-Instruct
curl -X POST http://10.109.40.169/v1/completions \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'"$MODEL_ID"'",
    "prompt": "You are a helpful AI assistant. Please introduce yourself in one sentence.",
  }'
```

### Bring Your Own Model

There is a default sample application that by loads [`meta-llama/Llama-3.2-3B-Instruct`](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct)
based on the sample application [values.yaml](../charts/llm-d/values.yaml) file. If you want to swap that model out with
another [vllm compatible model](https://docs.vllm.ai/en/latest/models/supported_models.html). Simply modify the
values file with the model you wish to run.

Here is an example snippet of the default model values being replaced with
[`meta-llama/Llama-3.2-1B-Instruct`](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct).

```yaml
  model:
    # -- Fully qualified pvc URI: pvc://<pvc-name>/<model-path>
    modelArtifactURI: pvc://llama-3.2-1b-instruct-pvc/models/meta-llama/Llama-3.2-1B-Instruct

    # # -- Fully qualified hf URI: pvc://<pvc-name>/<model-path>
    # modelArtifactURI: hf://meta-llama/Llama-3.2-3B-Instruct

    # -- Name of the model
    modelName: "Llama-3.2-1B-Instruct"

    # -- Aliases to the Model named vllm will serve with
    servedModelNames: []

    auth:
      # -- HF token auth config via k8s secret.
      hfToken:
        # -- If the secret should be created or one already exists
        create: true
        # -- Name of the secret to create to store your huggingface token
        name: llm-d-hf-token
        # -- Value of the token. Do not set this but use `envsubst` in conjunction with the helm chart
        key: HF_TOKEN

  downloadModelJob:
      # -- If `.Values.sampleApplication.model.modelArtifactURI` starts with `pvc://` what huggingface repo to load onto the pvc
    hfModelID: "meta-llama/Llama-3.2-1B-Instruct"
```

### Metrics Collection

llm-d includes built-in support for metrics collection using Prometheus and Grafana. This feature is enabled by default but can be disabled using the `--disable-metrics-collection` flag during installation.

#### Accessing the Metrics UIs

Once installed, you can access the metrics UIs through port-forwarding:

1. Prometheus UI (port 9090):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-kube-prometheus-prometheus 9090:9090
```

1. Grafana UI (port 3000):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-grafana 3000:80
```

Access the UIs at:

- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000> (default credentials: admin/admin)

#### Available Metrics

The metrics collection includes:

- Model inference performance metrics
- Request latency and throughput
- Resource utilization (CPU, memory, GPU)
- Cache hit/miss rates
- Error rates and types

#### Local Development Note

When running in Minikube:

1. The metrics UIs are accessible via localhost by default
2. If you need to access from another machine, use the Minikube IP address instead of localhost
3. The default credentials (admin/admin) should be changed in production environments

### Troubleshooting

The various images can take some time to download depending on your connectivity. Watching events
and logs of the prefill and decode pods is a good place to start.

### Uninstall

This will remove llm-d resources from the cluster. This is useful, especially for test/dev if you want to
make a change, simply uninstall and then run the installer again with any changes you make.

```bash
./llmd-installer-minikube.sh --uninstall
```

To remove the minikube cluster this simply wraps the minikube command for convenience.

```bash
./llmd-installer.sh --delete-minikube
```

To manually delete the running cluster run:

```bash
minikube delete
```
