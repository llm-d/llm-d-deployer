# llm-d Quick Start - Minikube

Getting Started with llm-d on minikube.

This guide will walk you through the steps to install and deploy llm-d on a minikube cluster, using an opinionated flow in order to get up and running as quickly as possible.

## Client Configuration

### Required tools

Following prerequisite are required for the installer to work.

- [yq (mikefarah) – installation](https://github.com/mikefarah/yq?tab=readme-ov-file#install)
- [jq – download & install guide](https://stedolan.github.io/jq/download/)
- [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [Kustomize – official install docs](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

You can use the installer script that installs all the required dependencies. This does not install CUDA components.

```bash
./install-deps.sh
```

### Required credentials and configuration

- [llm-d-deployer GitHub repo – clone here](https://github.com/llm-d/llm-d-deployer.git)
- [HuggingFace HF_TOKEN](https://huggingface.co/docs/hub/en/security-tokens)

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

- This can be run on a minimum ec2 node type [g6e.12xlarge](https://aws.amazon.com/ec2/instance-types/g6e/) (4xL40S 48GB but only 2 are used by default) to
infer the model `meta-llama/Llama-3.2-3B-Instruct` that will get spun up.
- You can also be run on a small [g6.2xlarge](https://aws.amazon.com/ec2/instance-types/g6/) with 1xL4 with a small model where both the prefill and
decode pods share the single GPU. This is useful for a quick deployment to familiarize yourself with the project or
for development/CI purposes. See the [Run on a Single GPU](#run-on-a-single-gpu) section for deploying.

#### Confirm GPU Access in Containers

Verify you have properly installed the container toolkit with the runtime of your choice.

```yaml
# Podman
podman run --rm --security-opt=label=disable --device=nvidia.com/gpu=all ubuntu nvidia-smi
# Docker
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

## Start your Minikube Cluster

```bash
minikube start \
    --driver docker \
    --container-runtime docker \
    --gpus all \
    --memory no-limit \
    --cpus no-limit
```

> Note: if you only have a single GPU, jump to the [Run on a Single GPU](#run-on-a-single-gpu) section.

If you want to skip straight to deploying, simply run:

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh --minikube
```

Minikube instances can be stopped and started. If you reboot the node the cluster is on, minikube will be in a
stopped state after reboot.

```bash
minikube stop
minikube start
```

## llm-d Installation

The llm-d-deployer contains all the helm charts necessary to deploy llm-d. To facilitate the installation of the
helm charts, the `llmd-installer.sh` script is provided. This script will populate the necessary
manifests in the `manifests` directory. After this, it will apply all the manifests in order to bring up the cluster.

Before proceeding with the installation, ensure you have installed the required dependencies

### Usage

The installer needs to be run from the `llm-d-deployer/quickstart` directory.

## Examples

For additional information regarding Minikube support with GPUs see [Using NVIDIA GPUs with minikube](https://minikube.sigs.k8s.io/docs/tutorials/nvidia/).

### Deploy llm-d on Minikube

A hugging-face token is required either exported in your environment or passed via the `--hf-token` flag.
You will need to have a running minikube instance. After that, a common workflow might be to make some change
to your code, run `llmd-installer.sh --uninstall` to reset the minikube cluster to default and then run the installer again to test
any code or configuration changes.

```bash
export HF_TOKEN="your-token"
# deploy
./llmd-installer.sh --minikube
# make some awesome change (if you are not using the default minikube context pass --minikube to uninstall)
./llmd-installer.sh --uninstall
# re-deploy
./llmd-installer.sh --minikube
```

### Run on a Single GPU

If you want to run on a single GPU such as [g6.2xlarge](https://aws.amazon.com/ec2/instance-types/g6/) with a 1xL4,
load the example values file that is tuned to fit on the 24GB GPU memory available. The models and vLLM flags in the
configuration files can be customized to be however you like. The following loads the base configuration with
[Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B).

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh --minikube --values-file examples/base/slim/base-slim.yaml
```

If you want to run both prefill and decode pods, use the following values file that will spin up both pods
on a 1xL4 (g6.2xlarge) node on your minikube cluster. In this scenario, we are offloading GPU memory to
RAM in order to squeeze the initial model loading memory spikes. You will likely need to disable metrics to
reduce memory pressure on a g6.2xlarge with 32GB of RAM. You can monitor available memory with the `free -h` command.

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh --minikube --values-file examples/pd-nixl/slim/pd-nixl-slim.yaml --disable-metrics-collection
```

### Customize your deployment

To make swapping in your own model even easier, we include a ready-to-use values files in[`quickstart/models/`](examples).

Simply run the installer with the path to the included values file (or your own custom one) deploy the llm-d
chart with all the correct overrides. These examples, also show you how you can pass custom arguments to vLLM
prefill and decode pods.

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh --minikube --values-file examples/<YOUR_CUSTOM_CONFIGURATION>.yaml
```

### Validation

The inference-gateway serves as the HTTP ingress point for all inference requests in our deployment.
It’s implemented as a Kubernetes Gateway (`gateway.networking.k8s.io/v1`) using whichever `gatewayClassName` you’ve
chosen, either `istio` or `kgateway` and sits in front of your inference pods to handle path-based routing, load-balancing,
retries, and metrics. All calls to `/v1/models` and `/v1/completions` flow through this gateway to the appropriate
`decode` or `prefill` services.

#### Step 1: Port-forward the llm-d-inference-gateway service

Open a terminal and run:

```bash
if kubectl get svc -n llm-d llm-d-inference-gateway-istio &>/dev/null; then
  kubectl port-forward -n llm-d svc/llm-d-inference-gateway-istio 3000:80 # port forward istio gateway
else
  kubectl port-forward -n llm-d svc/llm-d-inference-gateway 3000:80 # port forward kgateway gateway
fi
```

#### Step 2: Test the Inference Gateway with curl

In a new terminal, use `curl` to interact with the inference gateway:

```bash
# 1) List the available models and get the model ID
curl -s http://127.0.0.1:3000/v1/models
MODEL_ID=<INSERT_MODEL_NAME e.g. meta-llama/Llama-3.2-3B-Instruct, Qwen/Qwen3-0.6B, etc>

# 2) Send a completion request to the model
curl -X POST http://127.0.0.1:3000/v1/completions \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'"$MODEL_ID"'",
    "prompt": "You are a helpful AI assistant. Please introduce yourself in one sentence."
  }'
```

You can also run the included validation script `test-requests.sh --minikube`.

```bash
# Default options (the model id will be discovered via /v1/models)
./test-request.sh --minikube

# Non-default namespace/model
./test-request.sh -n <NAMESPACE> -m <FULL_MODEL_NAME> --minikube
```

### Bring Your Own Model

If you want to swap that model out with another [vllm compatible model](https://docs.vllm.ai/en/latest/models/supported_models.html), simply modify the values file in
the [quickstart/examples](./examples) directory with the model you wish to run.

### Metrics Collection

llm-d includes built-in support for metrics collection using Prometheus and Grafana. This feature is enabled by default but can be disabled using the `--disable-metrics-collection` flag during installation.
Prometheus and Grafana are installed from the prometheus-community [kube-prometheus-stack helm charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).
The [llm-d metrics overview](./metrics-overview.md) lists the metrics scraped with a default llm-d install.

#### Accessing the Metrics UIs

- Prometheus User Interface (port 9090):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-kube-prometheus-prometheus 9090:9090
```

- Grafana User Interface (port 3000):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-grafana 3000:80
```

Access the UIs at:

- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000> (default credentials: admin/admin)

#### Grafana Dashboards

Import the [llm-d dashboard](./grafana/dashboards/llm-d-dashboard.json) from the Grafana UI. Go to `Dashboards -> New -> Import`.
Similarly, import the [inference-gateway dashboard](https://github.com/kubernetes-sigs/gateway-api-inference-extension/blob/main/tools/dashboards/inference_gateway.json)
from the gateway-api-inference-extension repository.

#### Local Development Note

When running in Minikube:

1. The metrics UIs are accessible via localhost by default
2. If you need to access from another machine, use the Minikube IP address instead of localhost
3. The default credentials (admin/admin) should be changed in production environments

### Troubleshooting

The various images can take some time to download depending on your connectivity. Watching events
and logs of the pods, decode and prefill (if running prefill) is a good place to start to get an indication of
any issues.

```bash
# View the status of the pods in the default llm-d namespace. Replace "llm-d" if you used a custom namespace on install
kubectl get pods -n llm-d

# Describe all prefill pods:
kubectl describe pods -l llm-d.ai/role=prefill -n llm-d

# Fetch logs from each prefill pod:
kubectl logs -l llm-d.ai/role=prefill --all-containers=true -n llm-d --tail=200

# Describe all decode pods:
kubectl describe pods -l llm-d.ai/role=decode -n llm-d

# Fetch logs from each decode pod:
kubectl logs -l llm-d.ai/role=decode --all-containers=true -n llm-d --tail=200

# Describe all endpoint-picker pods:
kubectl describe pod -n llm-d -l llm-d.ai/epp

# Fetch logs from each endpoint-picker pod:
kubectl logs -n llm-d -l llm-d.ai/epp --all-containers=true --tail=200
```

### Delete the Minikube Cluster

To delete the Minikube cluster, simply run:

```bash
minikube delete
```
