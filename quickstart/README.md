# llm-d Quick Start

Getting Started with llm-d on Kubernetes.

For more information on llm-d, see the llm-d git repository [here](https://github.com/llm-d/llm-d) and website [here](https://llm-d.ai).

## Overview

This guide will walk you through the steps to install and deploy llm-d on a Kubernetes cluster, using an opinionated flow in order to get up and running as quickly as possible.

## Client Configuration

### Required tools

Following prerequisite are required for the installer to work.

- [yq (mikefarah) – installation](https://github.com/mikefarah/yq?tab=readme-ov-file#install)
- [jq – download & install guide](https://stedolan.github.io/jq/download/)
- [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [Kustomize – official install docs](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

You can use the installer script that installs all the required dependencies.  Currently only Linux is supported.

```bash
# Currently Linux only
./install-deps.sh
```

### Required credentials and configuration

- [llm-d-deployer GitHub repo – clone here](https://github.com/llm-d/llm-d-deployer.git)
- [ghcr.io Registry – credentials](https://github.com/settings/tokens) You must have a GitHub account and a "classic" personal access token with `read:packages` access to the llm-d-deployer repository.
- [Red Hat Registry – terms & access](https://access.redhat.com/registry/)
- [HuggingFace HF_TOKEN](https://huggingface.co/docs/hub/en/security-tokens) with download access for the model you want to use.  By default the sample application will use [meta-llama/Llama-3.2-3B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct).

> ⚠️ Your Hugging Face account must have access to the model you want to use.  You may need to visit Hugging Face [meta-llama/Llama-3.2-3B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct) and
> accept the usage terms if you have not already done so.

Registry Authentication: The installer looks for an auth file in:

```bash
~/.config/containers/auth.json
# or
~/.config/containers/config.json
```

If not found, you can create one with the following commands:

Create with Docker:

```bash
docker --config ~/.config/containers/ login ghcr.io
```

Create with Podman:

```bash
podman login ghcr.io --authfile ~/.config/containers/auth.json
```

### Target Platforms

#### Kubernetes

This can be run on a minimum ec2 node type [g6e.12xlarge](https://aws.amazon.com/ec2/instance-types/g6e/) (4xL40S 48GB but only 2 are used by default) to infer the model meta-llama/Llama-3.2-3B-Instruct that will get spun up.

> ⚠️ If your cluster has no available GPUs, the **prefill** and **decode** pods will remain in **Pending** state.

Verify you have properly installed the container toolkit with the runtime of your choice.

```bash
# Podman
podman run --rm --security-opt=label=disable --device=nvidia.com/gpu=all ubuntu nvidia-smi
# Docker
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

#### OpenShift

- OpenShift - This quickstart was tested on OpenShift 4.18. Older versions may work but have not been tested.
- NVIDIA GPU Operator and NFD Operator - The installation instructions can be found [here](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/steps-overview.html).
- NO Service Mesh or Istio installation as Istio CRDs will conflict with the gateway

## llm-d Installation

The llm-d-deployer contains all the helm charts necessary to deploy llm-d. To facilitate the installation of the helm charts, the `llmd-installer.sh` script is provided. This script will populate the necessary manifests in the `manifests` directory.
After this, it will apply all the manifests in order to bring up the cluster.

The llmd-installer.sh script aims to simplify the installation of llm-d using the llm-d-deployer as it's main function.  It scripts as many of the steps as possible to make the installation process more streamlined.  This includes:

- Installing the GAIE infrastructure
- Creating the namespace with any special configurations
- Creating the pull secret to download the images
- Creating the model service CRDs
- Applying the helm charts
- Deploying the sample app (model service)

It also supports uninstalling the llm-d infrastructure and the sample app.

Before proceeding with the installation, ensure you have completed the prerequisites and are able to issue kubectl commands to your cluster by configuring your `~/.kube/config` file or by using the `oc login` command.

### Usage

The installer needs to be run from the `llm-d-deployer/quickstart` directory.

```bash
./llmd-installer.sh [OPTIONS]
```

### Flags

| Flag                                | Description                                                                                             | Example                                                          |
|-------------------------------------|---------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| `-a`, `--auth-file PATH`             | Path to containers auth.json                                                                             | `./llmd-installer.sh --auth-file ~/.config/containers/auth.json` |
| `-z`, `--storage-size SIZE`          | Size of storage volume                                                                                   | `./llmd-installer.sh --storage-size 15Gi`                        |
| `-c`, `--storage-class CLASS`        | Storage class to use (default: efs-sc)                                                                  | `./llmd-installer.sh --storage-class ocs-storagecluster-cephfs`  |
| `-n`, `--namespace NAME`             | K8s namespace (default: llm-d)                                                                          | `./llmd-installer.sh --namespace foo`                            |
| `-f`, `--values-file PATH`           | Path to Helm values.yaml file (default: values.yaml)                                                     | `./llmd-installer.sh --values-file /path/to/values.yaml`         |
| `-u`, `--uninstall`                  | Uninstall the llm-d components from the current cluster                                                 | `./llmd-installer.sh --uninstall`                                |
| `-d`, `--debug`                      | Add debug mode to the helm install                                                                      | `./llmd-installer.sh --debug`                                    |
| `-i`, `--skip-infra`                 | Skip the infrastructure components of the installation                                                  | `./llmd-installer.sh --skip-infra`                               |
| `-m`, `--disable-metrics-collection` | Disable metrics collection (Prometheus will not be installed)                                           | `./llmd-installer.sh --disable-metrics-collection`               |
| `-s`, `--skip-download-model`        | Skip downloading the model to PVC if modelArtifactURI is pvc based                                      | `./llmd-installer.sh --skip-download-model`                      |
| `-h`, `--help`                       | Show this help and exit                                                                                 | `./llmd-installer.sh --help`                                     |

## Examples

### Install llm-d on an Existing Kubernetes Cluster

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh
```

### Install on OpenShift

Before running the installer, ensure you have logged into the cluster.  For example:

```bash
oc login --token=sha256~yourtoken --server=https://api.yourcluster.com:6443
```

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh
```

### Validation

The inference-gateway serves as the HTTP ingress point for all inference requests in our deployment.
It’s implemented as a Kubernetes Gateway (`gateway.networking.k8s.io/v1`) using either kgateway or istio as the
gatewayClassName, and sits in front of your inference pods to handle path-based routing, load balancing, retries,
and metrics. This example validates that the gateway itself is routing your completion requests correctly.
You can execute the [`test-request.sh`](test-request.sh) script to test on the cluster.

In addition, if you're using an OpenShift Cluster or have created an ingress, you can test the endpoint from an external location.

```bash
INGRESS_ADDRESS=$(kubectl get ingress -n "$NAMESPACE" | tail -n1 | awk '{print $3}')

curl -sS -X GET "http://${INGRESS_ADDRESS}/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'

MODEL_ID=meta-llama/Llama-3.2-3B-Instruct

curl -sS -X POST "http://${INGRESS_ADDRESS}/v1/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model":"'"$MODEL_ID"'",
    "prompt": "You are a helpful AI assistant. Please introduce yourself in one sentence.",
  }'
```

> If you receive an error indicating PodSecurity "restricted" violations when running the smoke-test script, you
> need to remove the restrictive PodSecurity labels from the namespace. Once these labels are removed, re-run the
> script and it should proceed without PodSecurity errors.
> Run the following command:

```bash
kubectl label namespace <NAMESPACE> \
  pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/warn-version- \
  pod-security.kubernetes.io/audit- \
  pod-security.kubernetes.io/audit-version-
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
      # -- HF token auth config via k8s secret. Required if using hf:// URI or not using pvc:// URI with `--skip-download-model` in quickstart
      hfToken:
        # -- If the secret should be created or one already exists
        create: true
        # -- Name of the secret to create to store your huggingface token
        name: llm-d-hf-token
        # -- Value of the token. Do not set this but use `envsubst` in conjunction with the helm chart
        key: HF_TOKEN
```

### Metrics Collection

llm-d includes built-in support for metrics collection using Prometheus and Grafana. This feature is enabled by default but can be disabled using the
`--disable-metrics-collection` flag during installation. In OpenShift, llm-d applies ServiceMonitors for llm-d components that trigger Prometheus
scrape targets for the built-in user workload monitoring Prometheus stack.

#### Accessing the Metrics UIs

If running in OpenShift, skip to [Option 3: OpenShift](#option-3-openshift).

##### Option 1: Port Forwarding (Default)

Once installed, you can access the metrics UIs through port-forwarding:

- Prometheus UI (port 9090):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-kube-prometheus-prometheus 9090:9090
```

- Grafana UI (port 3000):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-grafana 3000:80
```

Access the UIs at:

- Prometheus: <http://YOUR_IP:9090>
- Grafana: <http://YOUR_IP:3000> (default credentials: admin/admin)

##### Option 2: Ingress (Optional)

For production environments, you can configure ingress for both Prometheus and Grafana. Add the following to your values.yaml:

```yaml
prometheus:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
      - prometheus.your-domain.com
    tls:
      - secretName: prometheus-tls
        hosts:
          - prometheus.your-domain.com

grafana:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
      - grafana.your-domain.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.your-domain.com
```

##### Option 3: OpenShift

If you're using OpenShift with user workload monitoring enabled, you can access the metrics through the OpenShift console:

1. Navigate to the OpenShift console
2. In the left navigation bar, click on "Observe"
3. You can access:
   - Metrics: Click on "Metrics" to view and query metrics using the built-in Prometheus UI
   - Targets: Click on "Targets" to see all monitored endpoints and their status

The metrics are automatically integrated into the OpenShift monitoring stack, providing a seamless experience for viewing and analyzing your llm-d metrics.
The llm-d-deployer does not install Grafana in OpenShift, but it's recommended that users install Grafana to view metrics and import dashboards.

Follow the [OpenShift Grafana setup guide](https://github.com/llm-d/llm-d/blob/dev/observability/openshift/README.md#step-2-set-up-grafana-optional)
The guide includes manifests to install the following:

- Grafana instance
- Grafana Prometheus datasource from user workload monitoring stack
- Grafana llm-d dashboard

#### Available Metrics

The metrics collection includes:

- Model inference performance metrics
- Request latency and throughput
- Resource utilization (CPU, memory, GPU)
- Cache hit/miss rates
- Error rates and types

#### Security Note

When running in a cloud environment (like EC2), make sure to:

1. Configure your security groups to allow inbound traffic on ports 9090 and 3000 (if using port-forwarding)
2. Use the `--address 0.0.0.0` flag with port-forward to allow external access
3. Consider setting up proper authentication for production environments
4. If using ingress, ensure proper TLS configuration and authentication
5. For OpenShift, consider using the built-in OAuth integration for Grafana

### Troubleshooting

The various images can take some time to download depending on your connectivity. Watching events
and logs of the prefill and decode pods is a good place to start.

### Uninstall

This will remove llm-d resources from the cluster. This is useful, especially for test/dev if you want to
make a change, simply uninstall and then run the installer again with any changes you make.

```bash
./llmd-installer.sh --uninstall
```
