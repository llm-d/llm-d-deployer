#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

### GLOBALS ###
NAMESPACE="llm-d"
PROVISION_MINIKUBE=false
PROVISION_MINIKUBE_GPU=false
STORAGE_SIZE="15Gi"
DELETE_MINIKUBE=false
ACTION="install"
HF_TOKEN_CLI=""
AUTH_FILE_CLI=""
PULL_SECRET_NAME="llm-d-pull-secret"
SCRIPT_DIR=""
REPO_ROOT=""
INSTALL_DIR=""
CHART_DIR=""
HF_NAME=""
HF_KEY=""
PROXY_UID=""
AUTH_FILE=""
HOSTPATH_DIR=${HOSTPATH_DIR:="/mnt/data/llama-model-storage"}
VALUES_FILE="values.yaml"
DEBUG=""
DISABLE_METRICS=false
MONITORING_NAMESPACE="llm-d-monitoring"
MODEL_PV_NAME="llama-hostpath-pv"
MODEL_PVC_NAME="llama-3.2-3b-instruct-pvc"
REDIS_PV_NAME="redis-hostpath-pv"
REDIS_PVC_NAME="redis-data-redis-master"

### HELP & LOGGING ###
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --hf-token TOKEN           Hugging Face token (or set HF_TOKEN env var)
  --auth-file PATH           Path to containers auth.json
  --provision-minikube       Provision a local Minikube cluster without GPU support (p/d pods will stay pending)
  --provision-minikube-gpu   Provision a local Minikube cluster with GPU support
  --delete-minikube          Delete the minikube cluster and exit
  --storage-size SIZE        Size of storage volume (default: 15Gi)
  --namespace NAME           K8s namespace (default: llm-d)
  --values-file PATH         Path to Helm values.yaml file (default: values.yaml)
  --uninstall                Uninstall the llm-d components from the current cluster
  --debug                    Add debug mode to the helm install
  --disable-metrics-collection Disable metrics collection (Prometheus will not be installed)
  -h, --help                 Show this help and exit
EOF
}

log_info()    { echo -e "$*"; }
log_success() { echo -e "$*"; }
log_error()   { echo -e "❌ $*" >&2; }
die()         { log_error "$*"; exit 1; }

### UTILITIES ###
check_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

check_dependencies() {
  local required_cmds=(git yq jq helm kubectl kustomize make)
  for cmd in "${required_cmds[@]}"; do
    check_cmd "$cmd"
  done
}

check_cluster_reachability() {
  if kubectl cluster-info &> /dev/null; then
    log_info "kubectl can reach to a running Kubernetes cluster."
  else
    die "kubectl cannot reach any running Kubernetes cluster."
  fi
}

# Derive an OpenShift PROXY_UID; default to 0 if not available
fetch_kgateway_proxy_uid() {
  log_info "Fetching OCP proxy UID..."
  local uid_range
  uid_range=$(kubectl get namespace "${NAMESPACE}" -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' 2>/dev/null || true)
  if [[ -n "$uid_range" ]]; then
    PROXY_UID=$(echo "$uid_range" | awk -F'/' '{print $1 + 1}')
    log_success "Derived PROXY_UID=${PROXY_UID}"
  else
    PROXY_UID=0
    log_info "No OpenShift SCC annotation found; defaulting PROXY_UID=${PROXY_UID}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hf-token)               HF_TOKEN_CLI="$2"; shift 2 ;;
      --auth-file)              AUTH_FILE_CLI="$2"; shift 2 ;;
      --provision-minikube)     PROVISION_MINIKUBE=true; shift ;;
      --provision-minikube-gpu) PROVISION_MINIKUBE_GPU=true; shift ;;
      --delete-minikube)        DELETE_MINIKUBE=true; shift ;;
      --storage-size)           STORAGE_SIZE="$2"; shift 2 ;;
      --namespace)              NAMESPACE="$2"; shift 2 ;;
      --values-file)            VALUES_FILE="$2"; shift 2 ;;
      --uninstall)              ACTION="uninstall"; shift ;;
      --debug)                  DEBUG="--debug"; shift;;
      --disable-metrics-collection) DISABLE_METRICS=true; shift;;
      -h|--help)                print_help; exit 0 ;;
      *)                        die "Unknown option: $1" ;;
    esac
  done
}

### ENV & PATH SETUP ###
setup_env() {
  log_info "📂 Setting up script environment..."
  SCRIPT_DIR=$(realpath "$(pwd)")
  REPO_ROOT=$(git rev-parse --show-toplevel)
  INSTALL_DIR=$(realpath "${REPO_ROOT}/quickstart")
  CHART_DIR=$(realpath "${REPO_ROOT}/charts/llm-d")

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    die "Script must be run from ${INSTALL_DIR}"
  fi
}

locate_auth_file() {
  log_info "🔑 Locating container auth file..."
  if [[ -n "$AUTH_FILE_CLI" && -f "$AUTH_FILE_CLI" ]]; then
    AUTH_FILE="$AUTH_FILE_CLI"
  elif [[ -f "$HOME/.config/containers/auth.json" ]]; then
    AUTH_FILE="$HOME/.config/containers/auth.json"
  elif [[ -f "$HOME/.config/containers/config.json" ]]; then
    AUTH_FILE="$HOME/.config/containers/config.json"
  else
    echo "No auth file found in ~/.config/containers/"
    echo "Please authenticate with either:"
    echo
    echo "# Docker"
    echo "docker --config ~/.config/containers/ login quay.io"
    echo
    echo "# Podman"
    echo "podman login quay.io  --authfile ~/.config/containers/auth.json"
    exit 1
  fi
  log_success "✅ Auth file: ${AUTH_FILE}"
}

validate_hf_token() {
  if [[ "$ACTION" == "install" ]]; then
    log_info "🤖 Validating Hugging Face token..."
    HF_TOKEN="${HF_TOKEN_CLI:-${HF_TOKEN:-}}"
    [[ -n "$HF_TOKEN" ]] || die "HF_TOKEN not set."
    log_success "✅ HF_TOKEN validated"
  fi
}

### MINIKUBE HANDLERS ###
provision_minikube() {
  log_info "🌱 Provisioning Minikube cluster..."
  minikube start
  log_success "🚀 Minikube started."
}

provision_minikube_gpu() {
  log_info "🌱 Provisioning Minikube GPU cluster…"
  minikube start \
    --driver docker \
    --container-runtime docker \
    --gpus all
  log_success "🚀 Minikube GPU cluster started."
}

install_prometheus_grafana() {
  log_info "🌱 Provisioning Prometheus operator…"

  if ! kubectl get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "📦 Creating monitoring namespace..."
    kubectl create namespace "${MONITORING_NAMESPACE}"
  else
    log_info "📦 Monitoring namespace already exists"
  fi

  if ! helm repo list 2>/dev/null | grep -q "prometheus-community"; then
    log_info "📚 Adding prometheus-community helm repo..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
  fi

  if helm list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus"; then
    log_info "⚠️ Prometheus stack already installed in ${MONITORING_NAMESPACE} namespace"
    return 0
  fi

  log_info "🚀 Installing Prometheus stack..."
  # Install minimal Prometheus stack with only essential configurations:
  # - Basic ClusterIP services for Prometheus and Grafana
  # - ServiceMonitor discovery enabled across namespaces
  # - Default admin password for Grafana
  # Note: Ingress and other advanced configurations are left to the user to customize
  cat <<EOF > /tmp/prometheus-values.yaml
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
prometheus:
  service:
    type: ClusterIP
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
EOF

  helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NAMESPACE}" \
    -f /tmp/prometheus-values.yaml

  rm -f /tmp/prometheus-values.yaml

  log_info "⏳ Waiting for Prometheus stack pods to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "${MONITORING_NAMESPACE}" --timeout=300s || true
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n "${MONITORING_NAMESPACE}" --timeout=300s || true

  log_success "🚀 Prometheus and Grafana installed."
}

delete_minikube() {
  log_info "🗑️ Deleting Minikube cluster..."
  minikube delete
  log_success "🙀 Minikube deleted."
}

install() {
  log_info "🏗️ Installing GAIE Kubernetes infrastructure…"
  clone_gaie_repo
  pushd gateway-api-inference-extension >/dev/null
    INFRASTRUCTURE_OVERRIDE=true make environment.dev.kubernetes.infrastructure
  popd >/dev/null
  rm -rf gateway-api-inference-extension
  log_success "✅ GAIE infra applied"
  log_info "📦 Creating namespace ${NAMESPACE}..."
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl config set-context --current --namespace="${NAMESPACE}"
  log_success "✅ Namespace ready"

  log_info "🔐 Creating pull secret ${PULL_SECRET_NAME}..."
  kubectl create secret generic "${PULL_SECRET_NAME}" \
    -n "${NAMESPACE}" \
    --from-file=.dockerconfigjson="${AUTH_FILE}" \
    --type=kubernetes.io/dockerconfigjson \
    --dry-run=client -o yaml | kubectl apply -f -
  log_success "✅ Pull secret created"

  log_info "🔧 Patching default ServiceAccount..."
  kubectl patch serviceaccount default \
    -n "${NAMESPACE}" \
    --type merge \
    --patch '{"imagePullSecrets":[{"name":"'"${PULL_SECRET_NAME}"'"}]}'
  log_success "✅ ServiceAccount patched"

  cd "${CHART_DIR}"
  # Resolve which values.yaml to use:
  #   - If the user passed --values-file (i.e. $VALUES_FILE != "values.yaml"), treat it as
  #     either relative or absolute path and require it to exist.
  #   - Otherwise default to $CHART_DIR/values.yaml.
  if [[ "$VALUES_FILE" != "values.yaml" ]]; then
    if [[ -f "$VALUES_FILE" ]]; then
      VALUES_PATH=$(realpath "$VALUES_FILE")
      log_info "✅ Using custom values file: ${VALUES_PATH}"
    else
      die "Custom values file not found: $VALUES_FILE"
    fi
  else
    VALUES_PATH="${CHART_DIR}/values.yaml"
  fi

  if [[ "$(yq -r .auth.hfToken.enabled "${VALUES_PATH}")" == "true" ]]; then
    log_info "🔐 Creating HF token secret (from ${VALUES_PATH})..."
    HF_NAME=$(yq -r .auth.hfToken.name "${VALUES_PATH}")
    HF_KEY=$(yq -r .auth.hfToken.key  "${VALUES_PATH}")
    kubectl create secret generic "${HF_NAME}" \
      --from-literal="${HF_KEY}=${HF_TOKEN}" \
      --dry-run=client -o yaml | kubectl apply -f -
    log_success "✅ HF token secret created"
  fi

  fetch_kgateway_proxy_uid

  log_info "📜 Applying modelservice CRD..."
  kubectl apply -f crds/modelservice-crd.yaml
  log_success "✅ ModelService CRD applied"

  log_info "📝 Patching load-model job manifest with HF secret name='${HF_NAME}', key='${HF_KEY}'"
  # try brew's yq first; if that fails, fall back to linux installed pkg syntax -_-
  if ! yq -i ".spec.template.spec.containers[0].env[0].valueFrom.secretKeyRef.name = \"${HF_NAME}\"" "${REPO_ROOT}/helpers/k8s/load-model-on-pvc.yaml"; then
    yq -i -y ".spec.template.spec.containers[0].env[0].valueFrom.secretKeyRef.name = \"${HF_NAME}\"" "${REPO_ROOT}/helpers/k8s/load-model-on-pvc.yaml"
  fi
  if ! yq -i ".spec.template.spec.containers[0].env[0].valueFrom.secretKeyRef.key  = \"${HF_KEY}\""  "${REPO_ROOT}/helpers/k8s/load-model-on-pvc.yaml"; then
    yq -i -y ".spec.template.spec.containers[0].env[0].valueFrom.secretKeyRef.key  = \"${HF_KEY}\""  "${REPO_ROOT}/helpers/k8s/load-model-on-pvc.yaml"
  fi
  log_success "✅ Job manifest patched"

    setup_minikube_storage

  log_info "Checking for a storage class..."
  STORAGE_CLASSES=$(kubectl get sc ${STORAGE_CLASS} 2>/dev/null || true)
  if [[ -z "$STORAGE_CLASSES" ]]; then
    log_error "The defined storage class was not found; please create one"
    exit 1
  fi
  log_success "✅ Storage class found: ${STORAGE_CLASS}"

  log_info "🚀 Launching model download job..."
  kubectl apply -f "${REPO_ROOT}/helpers/k8s/load-model-on-pvc.yaml" -n "${NAMESPACE}"

  log_info "⏳ Waiting up to 3m for model download job to complete; this may take a while depending on connection speed and model size..."
  kubectl wait --for=condition=complete --timeout=180s job/download-model -n "${NAMESPACE}" || {
    log_error "🙀 Model download job failed or timed out";
    kubectl logs job/download-model -n "${NAMESPACE}";
    kubectl logs -l job-name=download-model -n "${NAMESPACE}";
    exit 1;
  }
  log_success "✅ Model downloaded"

  helm repo add bitnami  https://charts.bitnami.com/bitnami
  log_info "🛠️ Building Helm chart dependencies..."
  helm dependency build .
  log_success "✅ Dependencies built"

  log_info "🚚 Deploying llm-d chart with ${VALUES_PATH}..."
  helm upgrade -i llm-d . \
    ${DEBUG} \
    --namespace "${NAMESPACE}" \
    --values "${VALUES_PATH}" \
    --set gateway.kGatewayParameters.proxyUID="${PROXY_UID}"
  log_success "✅ llm-d deployed"

  log_info "🔄 Patching all ServiceAccounts with pull-secret..."
  patch='{"imagePullSecrets":[{"name":"'"${PULL_SECRET_NAME}"'"}]}'
  kubectl get deployments -n "${NAMESPACE}" -o jsonpath='{.items[*].spec.template.spec.serviceAccountName}' |
    tr ' ' '\n' | sort -u |
    xargs -I{} kubectl patch serviceaccount {} --namespace="${NAMESPACE}" --type merge --patch "${patch}"
  kubectl patch serviceaccount default --namespace="${NAMESPACE}" --type merge --patch "${patch}"
  log_success "✅ ServiceAccounts patched"

  MODELSERVICE_POD=$(kubectl get pods -n "${NAMESPACE}" | grep "modelservice" | awk 'NR==1{print $1}')
  log_info "🔁 Restarting pod ${MODELSERVICE_POD} to pick up new image..."
  kubectl delete pod "${MODELSERVICE_POD}" -n "${NAMESPACE}" || true

  log_info "🔄 Creating shared hostpath for Minicube PV and PVC for Redis..."
  kubectl delete pvc redis-pvc -n "${NAMESPACE}" --ignore-not-found
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${REDIS_PV_NAME}
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: ${HOSTPATH_DIR}/redis-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${REDIS_PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  volumeName: ${REDIS_PV_NAME}
EOF
  log_success "✅ Redis PV and PVC created with Helm annotations."

  post_install

  log_success "🎉 Installation complete."
}

setup_minikube_storage() {
  log_info "📦 Setting up Minikube hostPath RWX Shared Storage..."
  log_info "🔄 Creating PV and PVC for llama model..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${MODEL_PV_NAME}
spec:
  storageClassName: manual
  capacity:
    storage: ${STORAGE_SIZE}
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: ${HOSTPATH_DIR}
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${MODEL_PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  volumeName: ${MODEL_PV_NAME}
EOF
  log_success "✅ llama model PV and PVC created."
}

clone_gaie_repo() {
  if [[ ! -d gateway-api-inference-extension ]]; then
    git clone https://github.com/neuralmagic/gateway-api-inference-extension.git
  fi
}

# function called right before the installer exits
post_install() {
  # download-model pod deletion if it exists and in a succeeded phase
  local pod
  pod=$(kubectl get pods -n "${NAMESPACE}" \
    -l job-name=download-model \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$pod" ]]; then
    return
  fi
  local phase
  phase=$(kubectl get pod "$pod" -n "${NAMESPACE}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$phase" == "Succeeded" ]]; then
    kubectl delete pod "$pod" -n "${NAMESPACE}" --ignore-not-found || true
    log_success "🧹 download-model pod deleted"
  else
    log_info "→ Pod ${pod} phase is ${phase}; skipping delete."
  fi
}

uninstall() {
  log_info "🗑️ Tearing down GAIE Kubernetes infrastructure…"
  clone_gaie_repo
  pushd gateway-api-inference-extension >/dev/null
    INFRASTRUCTURE_OVERRIDE=true make clean.environment.dev.kubernetes.infrastructure
  popd >/dev/null
  rm -rf gateway-api-inference-extension
  # Check if we installed the Prometheus stack and delete the ServiceMonitor CRD if we did
  if helm list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus" 2>/dev/null; then
    log_info "🗑️ Deleting ServiceMonitor CRD..."
    kubectl delete crd servicemonitors.monitoring.coreos.com --ignore-not-found || true
  fi
  log_info "🗑️ Uninstalling llm-d chart..."
  helm uninstall llm-d --namespace "${NAMESPACE}" || true
  log_info "🗑️ Deleting namespace ${NAMESPACE}..."
  kubectl delete namespace "${NAMESPACE}" || true
  log_info "🗑️ Deleting monitoring namespace..."
  kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found || true


  log_info "🗑️ Deleting PVCs..."
  kubectl delete pv llama-hostpath-pv --ignore-not-found
  kubectl delete pvc redis-pvc -n "${NAMESPACE}" --ignore-not-found
  kubectl delete pv redis-hostpath-pv --ignore-not-found
  log_success "💀 Uninstallation complete"
}

main() {
  parse_args "$@"

  # If only deleting Minikube, do that and exit immediately
  if [[ "$DELETE_MINIKUBE" == true ]]; then
    check_cmd minikube
    delete_minikube
    exit 0
  fi

  setup_env
  check_dependencies

  # only check kubectl if not provisioning Minikube
  if [[ "$PROVISION_MINIKUBE" != "true" && "$PROVISION_MINIKUBE_GPU" != "true" ]]; then
    check_cluster_reachability
  fi

  locate_auth_file
  validate_hf_token

  if [[ "$ACTION" == "install" ]]; then
    if [[ "$PROVISION_MINIKUBE_GPU" == "true" ]]; then
      provision_minikube_gpu
      if [[ "${DISABLE_METRICS}" == "false" ]]; then
        install_prometheus_grafana
      else
        log_info "ℹ️ Metrics collection disabled by user request"
      fi
    elif [[ "$PROVISION_MINIKUBE" == "true" ]]; then
      provision_minikube
      if [[ "${DISABLE_METRICS}" == "false" ]]; then
        install_prometheus_grafana
      else
        log_info "ℹ️ Metrics collection disabled by user request"
      fi
    fi
    if [[ "${DISABLE_METRICS}" == "false" ]]; then
      install_prometheus_grafana
    else
      log_info "ℹ️ Metrics collection disabled by user request"
    fi
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
