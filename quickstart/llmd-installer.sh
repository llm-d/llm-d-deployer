#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

### GLOBALS ###
NAMESPACE="llm-d"
STORAGE_SIZE="7Gi"
STORAGE_CLASS="efs-sc"
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
VALUES_FILE="values.yaml"
DEBUG=""
SKIP_INFRA=false
DISABLE_METRICS=false
MONITORING_NAMESPACE="llm-d-monitoring"
DOWNLOAD_MODEL=true

### HELP & LOGGING ###
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --hf-token TOKEN           Hugging Face token (or set HF_TOKEN env var)
  --auth-file PATH           Path to containers auth.json
  --storage-size SIZE        Size of storage volume (default: 7Gi)
  --storage-class CLASS      Storage class to use (default: efs-sc)
  --namespace NAME           K8s namespace (default: llm-d)
  --values-file PATH         Path to Helm values.yaml file (default: values.yaml)
  --uninstall                Uninstall the llm-d components from the current cluster
  --debug                    Add debug mode to the helm install
  --skip-infra               Skip the infrastructure components of the installation
  --disable-metrics-collection Disable metrics collection (Prometheus will not be installed)
  -s, --skip-download-model  Skip downloading the model to PVC if modelArtifactURI is pvc based
  -h, --help                 Show this help and exit
EOF
}

log_info()      { echo -e "$*"; }
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
    die "kubectl cannot reach any running Kubernetes cluster. The installer requires a running cluster"
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
      --hf-token)                   HF_TOKEN_CLI="$2"; shift 2 ;;
      --auth-file)                  AUTH_FILE_CLI="$2"; shift 2 ;;
      --storage-size)               STORAGE_SIZE="$2"; shift 2 ;;
      --storage-class)              STORAGE_CLASS="$2"; shift 2 ;;
      --namespace)                  NAMESPACE="$2"; shift 2 ;;
      --values-file)                VALUES_FILE="$2"; shift 2 ;;
      --uninstall)                  ACTION="uninstall"; shift ;;
      --debug)                      DEBUG="--debug"; shift;;
      --skip-infra)                 SKIP_INFRA=true; shift;;
      --disable-metrics-collection) DISABLE_METRICS=true; shift;;
      -d)                           DOWNLOAD_MODEL=true; shift;;
      -s|--skip-download-model)     DOWNLOAD_MODEL=false; shift ;;
      -h|--help)                    print_help; exit 0 ;;
      *)                            die "Unknown option: $1" ;;
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

clone_gaie_repo() {
  if [[ ! -d gateway-api-inference-extension ]]; then
    git clone --branch main https://github.com/neuralmagic/gateway-api-inference-extension.git
  fi
}

create_pvc_and_download_model_if_needed() {
  YQ_TYPE=$(yq --version 2>/dev/null | grep -q 'version' && echo 'go' || echo 'py')
  MODEL_ARTIFACT_URI=$(cat ${VALUES_PATH} | yq .sampleApplication.model.modelArtifactURI)
  PROTOCOL="${MODEL_ARTIFACT_URI%%://*}"

  verify_env() {
    if [[ -z "${MODEL_ARTIFACT_URI}" ]]; then
        log_error "No Model Artifact URI set. Please set the \`.sampleApplication.model.modelArtifactURI\` in the values file."
        exit 1
    fi
    if [[ -z "${HF_MODEL_ID}" ]]; then
        log_error "Error, \`modelArtifactURI\` indicates model from PVC, but no Hugging Face model is defined.
        Please set the \`.sampleApplication.model.modelName\` in the values file."
        exit 1
    fi
    if [[ "${HF_MODEL_ID}" == *"/"* ]]; then
        log_error "Error, \`modelArtifactURI\` indicates model from PVC, but no Hugging Face model is defined.
        Please set the \`.sampleApplication.model.modelName\` in a Hugging Face compliant format `<org>/<repo>`."
        exit 1
    fi
    if [[ -z "${HF_TOKEN_SECRET_NAME}" ]]; then
        log_error "Error, no HF token secret name. Please set the \`.sampleApplication.model.auth.hfToken.name\` in the values file."
        exit 1
    fi
    if [[ -z "${HF_TOKEN_SECRET_KEY}" ]]; then
        log_error "Error, no HF token secret key. Please set the \`.sampleApplication.model.auth.hfToken.key\` in the values file."
        exit 1
    fi
    if [[ -z "${PVC_NAME}" ]]; then
        log_error "Invalid \$MODEL_ARTIFACT_URI, could not parse PVC name out of \`.sampleApplication.model.modelArtifactURI\`."
        exit 1
    fi
    if [[ -z "${MODEL_PATH}" ]]; then
        log_error "Invalid \$MODEL_ARTIFACT_URI, could not parse Model Path out of \`.sampleApplication.model.modelArtifactURI\`."
        exit 1
    fi
  }

  case "$PROTOCOL" in
  pvc)
    # Used in both conditionals, for logging in else
    PVC_AND_MODEL_PATH="${MODEL_ARTIFACT_URI#*://}"
    PVC_NAME="${PVC_AND_MODEL_PATH%%/*}"
    MODEL_PATH="${PVC_AND_MODEL_PATH#*/}"
    if [[ "${DOWNLOAD_MODEL}" == "true" ]]; then
      log_info "💾 Provisioning model storage…"

      HF_MODEL_ID=$(cat ${VALUES_PATH} | yq .sampleApplication.model.modelName)
      HF_TOKEN_SECRET_NAME=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.name)
      HF_TOKEN_SECRET_KEY=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.key)

      DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH=$(realpath "${REPO_ROOT}/helpers/k8s/load-model-on-pvc-template.yaml")

      verify_env

      log_info "Identify if storage class exists..."
      if ! kubectl get storageclass "${STORAGE_CLASS}" &>/dev/null; then
        log_error "Storage class \`${STORAGE_CLASS}\` not found. Please create it before attempting to pull the model."
        exit 1
      fi

      eval "echo \"$(cat ${REPO_ROOT}/helpers/k8s/model-storage-rwx-pvc-template.yaml)\"" \
        | kubectl apply -n "${NAMESPACE}" -f -
      log_success "✅ PVC \`${PVC_NAME}\` created with storageClassName ${STORAGE_CLASS} and size ${STORAGE_SIZE}"

      log_info "🚀 Launching model download job..."
      if [[ "${YQ_TYPE}" == "go" ]]; then
        yq eval "
        (.spec.template.spec.containers[0].env[] | select(.name == \"MODEL_PATH\")).value = \"${MODEL_PATH}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_MODEL_ID\")).value = \"${HF_MODEL_ID}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.name = \"${HF_TOKEN_SECRET_NAME}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.key = \"${HF_TOKEN_SECRET_KEY}\" |
        (.spec.template.spec.volumes[] | select(.name == \"model-cache\")).persistentVolumeClaim.claimName = \"${PVC_NAME}\"
        " "${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH}" | kubectl apply -f -
      elif [[ "${YQ_TYPE}" == "py" ]]; then
        kubectl apply -f ${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH} --dry-run=client -o yaml |
        yq -r | \
        jq \
        --arg modelPath "${MODEL_PATH}" \
        --arg hfModelId "${HF_MODEL_ID}" \
        --arg hfTokenSecretName "${HF_TOKEN_SECRET_NAME}" \
        --arg hfTokenSecretKey "${HF_TOKEN_SECRET_KEY}" \
        --arg pvcName "${PVC_NAME}" \
        '
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "MODEL_PATH")).value = $modelPath |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_MODEL_ID")).value = $hfModelId |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.name = $hfTokenSecretName |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.key = $hfTokenSecretKey |
        (.spec.template.spec.volumes[] | select(.name == "model-cache")).persistentVolumeClaim.claimName = $pvcName
        ' | yq -y | kubectl apply -n ${NAMESPACE} -f -
      else
        log_error "unrecognized yq distro -- error"
        exit 1
      fi

      log_info "⏳ Waiting 30 seconds pod to start running model download job ..."
      kubectl wait --for=condition=Ready pod/$(kubectl get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name') --timeout=60s || {
        log_error "🙀 No pod picked up model download job";
        log_info "Please check your storageclass configuration for the \`download-model\` - if the PVC fails to spin the job will never get a pod"
        kubectl logs job/download-model -n "${NAMESPACE}";
      }

      log_info "⏳ Waiting up to 3m for model download job to complete; this may take a while depending on connection speed and model size..."
      kubectl wait --for=condition=complete --timeout=180s job/download-model -n "${NAMESPACE}" || {
        log_error "🙀 Model download job failed or timed out";
        JOB_POD=$(kubectl get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name')
        kubectl logs pod/${JOB_POD} -n "${NAMESPACE}";
        exit 1;
      }

      log_success "✅ Model downloaded"
    else
      log_info "⏭️ Model download to PVC skipped: \`--skip-download-model\` flag set, assuming PVC ${PVC_NAME} exists and contains model at path: \`${MODEL_PATH}\`."
    fi
    ;;
  hf)
    log_info "⏭️ Model download to PVC skipped: BYO model via HF repo_id selected."
    echo "protocol hf chosen - models will be downloaded JIT in inferencing pods."
    ;;
  *)
    log_error "🤮 Unsupported protocol: $PROTOCOL. Check back soon for more supported types of model source 😉."
    exit 1
    ;;
  esac
}

install() {
  if [[ "${SKIP_INFRA}" == "false" ]]; then
    log_info "🏗️ Installing GAIE Kubernetes infrastructure…"
    clone_gaie_repo
    pushd gateway-api-inference-extension >/dev/null
      INFRASTRUCTURE_OVERRIDE=true make environment.dev.kubernetes.infrastructure
    popd >/dev/null
    rm -rf gateway-api-inference-extension
    log_success "✅ GAIE infra applied"
  fi

  if kubectl get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "🧹 Cleaning up existing monitoring namespace..."
    kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found
  fi

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

  if [[ "$(yq -r .sampleApplication.model.auth.hfToken.create "${VALUES_PATH}")" == "true" ]]; then
    log_info "🔐 Creating HF token secret (from ${VALUES_PATH})..."
    HF_NAME=$(yq -r .sampleApplication.model.auth.hfToken.name "${VALUES_PATH}")
    HF_KEY=$(yq -r .sampleApplication.model.auth.hfToken.key  "${VALUES_PATH}")
    kubectl create secret generic "${HF_NAME}" \
      --from-literal="${HF_KEY}=${HF_TOKEN}" \
      --dry-run=client -o yaml | kubectl apply -f -
    log_success "✅ HF token secret created"
  fi

  # can be fetched non-invasily if using kgateway or not
  fetch_kgateway_proxy_uid

  log_info "📜 Applying modelservice CRD..."
  kubectl apply -f crds/modelservice-crd.yaml
  log_success "✅ ModelService CRD applied"

  create_pvc_and_download_model_if_needed

  helm repo add bitnami  https://charts.bitnami.com/bitnami
  log_info "🛠️ Building Helm chart dependencies..."
  helm dependency build .
  log_success "✅ Dependencies built"

  BASE_OCP_DOMAIN=$(kubectl get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')

  local metrics_enabled="true"
  if [[ "${DISABLE_METRICS}" == "true" ]]; then
    metrics_enabled="false"
    log_info "ℹ️ Metrics collection disabled by user request"
  elif ! check_servicemonitor_crd; then
    log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found"
  fi

  if is_openshift; then
    if ! check_openshift_monitoring; then
      log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled"
    fi
    log_info "ℹ️ Using OpenShift's built-in monitoring stack"
    DISABLE_METRICS=true # don't install prometheus if in OpenShift
    metrics_enabled="true"
  fi

  # Install Prometheus if not disabled, not on OpenShift, and ServiceMonitor CRD doesn't exist
  if [[ "${DISABLE_METRICS}" == "false" ]]; then
    if ! check_servicemonitor_crd; then
      install_prometheus_grafana
    else
      log_info "ℹ️ Skipping Prometheus installation as ServiceMonitor CRD already exists"
    fi
  fi

  log_info "🚚 Deploying llm-d chart with ${VALUES_PATH}..."
  helm upgrade -i llm-d . \
    ${DEBUG} \
    --namespace "${NAMESPACE}" \
    --values "${VALUES_PATH}" \
    --set global.imagePullSecrets[0]=llm-d-pull-secret \
    --set gateway.kGatewayParameters.proxyUID="${PROXY_UID}" \
    --set ingress.clusterRouterBase="${BASE_OCP_DOMAIN}" \
    --set modelservice.metrics.enabled="${metrics_enabled}"
  log_success "✅ llm-d deployed"

  log_info "🔄 Patching all ServiceAccounts with pull-secret..."
  patch='{"imagePullSecrets":[{"name":"'"${PULL_SECRET_NAME}"'"}]}'
  kubectl get deployments -n "${NAMESPACE}" -o jsonpath='{.items[*].spec.template.spec.serviceAccountName}' |
    tr ' ' '\n' | sort -u |
    xargs -I{} kubectl patch serviceaccount {} --namespace="${NAMESPACE}" --type merge --patch "${patch}"
  kubectl patch serviceaccount default --namespace="${NAMESPACE}" --type merge --patch "${patch}"
  log_success "✅ ServiceAccounts patched"

  post_install

  log_success "🎉 Installation complete."
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
  if [[ "${SKIP_INFRA}" == "false" ]]; then
    log_info "🗑️ Tearing down GAIE Kubernetes infrastructure…"
    clone_gaie_repo
    pushd gateway-api-inference-extension >/dev/null
      INFRASTRUCTURE_OVERRIDE=true make clean.environment.dev.kubernetes.infrastructure
    popd >/dev/null
    rm -rf gateway-api-inference-extension
  fi
  MODEL_ARTIFACT_URI=$(kubectl get modelservice --ignore-not-found -n ${NAMESPACE} -o yaml | yq '.items[].spec.modelArtifacts.uri')
  PROTOCOL="${MODEL_ARTIFACT_URI%%://*}"
  if [[ "${PROTOCOL}" == "pvc" ]]; then
    INFERENCING_DEPLOYMENT=$(kubectl get deployments --ignore-not-found  -n ${NAMESPACE} -l llm-d.ai/inferenceServing=true | tail -n 1 | awk '{print $1}')
    PVC_NAME=$( kubectl get deployments --ignore-not-found  $INFERENCING_DEPLOYMENT -n ${NAMESPACE} -o yaml | yq '.spec.template.spec.volumes[] | select(has("persistentVolumeClaim"))' | yq .claimName)
    PV_NAME=$(kubectl get pvc ${PVC_NAME} --ignore-not-found  -n ${NAMESPACE} -o yaml | yq .spec.volumeName)
    kubectl delete job download-model --ignore-not-found || true
  fi
  log_info "🗑️ Uninstalling llm-d chart..."
  helm uninstall llm-d --ignore-not-found --namespace "${NAMESPACE}" || true

  log_info "🗑️ Deleting namespace ${NAMESPACE}..."
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found || true

  log_info "🗑️ Deleting monitoring namespace..."
  kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found || true

  # Check if we installed the Prometheus stack and delete the ServiceMonitor CRD if we did
  if helm list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus" 2>/dev/null; then
    log_info "🗑️ Deleting ServiceMonitor CRD..."
    kubectl delete crd servicemonitors.monitoring.coreos.com --ignore-not-found || true
  fi

  if [[ "${PROTOCOL}" == "pvc" ]]; then
    # enforce PV cleanup - PVC should go with namespace
    if [[ -n ${PV_NAME} ]]; then
      log_info "🗑️ Deleting Model PV..."
      kubectl delete pv ${PV_NAME} --ignore-not-found
    fi
  else
    log_info "⏭️ skipping deletion of PV and PVCS..."
  fi
  log_success "💀 Uninstallation complete"
}

check_servicemonitor_crd() {
  log_info "🔍 Checking for ServiceMonitor CRD (monitoring.coreos.com)..."
  if ! kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found"
    return 1
  fi

  API_VERSION=$(kubectl get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.spec.versions[?(@.served)].name}' 2>/dev/null || echo "")

  if [[ -z "$API_VERSION" ]]; then
    log_info "⚠️ Could not determine ServiceMonitor CRD API version"
    return 1
  fi

  if [[ "$API_VERSION" == "v1" ]]; then
    log_success "✅ ServiceMonitor CRD (monitoring.coreos.com/v1) found"
    return 0
  else
    log_info "⚠️ Found ServiceMonitor CRD but with unexpected API version: ${API_VERSION}"
    return 1
  fi
}

check_openshift_monitoring() {
  if ! is_openshift; then
    return 0
  fi

  log_info "🔍 Checking OpenShift user workload monitoring configuration..."

  # Check if user workload monitoring is enabled
  if ! kubectl get configmap cluster-monitoring-config -n openshift-monitoring -o yaml | grep -q "enableUserWorkload: true"; then
    log_info "⚠️ OpenShift user workload monitoring is not enabled"
    log_info "⚠️ To enable metrics collection in OpenShift, please enable user workload monitoring:"
    log_info "   oc create -f - <<EOF"
    log_info "   apiVersion: v1"
    log_info "   kind: ConfigMap"
    log_info "   metadata:"
    log_info "     name: cluster-monitoring-config"
    log_info "     namespace: openshift-monitoring"
    log_info "   data:"
    log_info "     config.yaml: |"
    log_info "       enableUserWorkload: true"
    log_info "   EOF"
    return 1
  fi

  log_success "✅ OpenShift user workload monitoring is properly configured"
  return 0
}

is_openshift() {
  # Check for OpenShift-specific resources
  if kubectl get clusterversion &>/dev/null; then
    return 0
  fi
  return 1
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
    -f /tmp/prometheus-values.yaml \
    1>/dev/null

  rm -f /tmp/prometheus-values.yaml

  log_info "⏳ Waiting for Prometheus stack pods to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "${MONITORING_NAMESPACE}" --timeout=300s || true
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n "${MONITORING_NAMESPACE}" --timeout=300s || true

  log_success "🚀 Prometheus and Grafana installed."
}

main() {
  parse_args "$@"

  setup_env
  check_dependencies

  # Check cluster reachability as a pre-requisite
  check_cluster_reachability

  locate_auth_file
  validate_hf_token

  if [[ "$ACTION" == "install" ]]; then
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
