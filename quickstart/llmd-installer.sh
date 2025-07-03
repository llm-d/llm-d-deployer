#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

### GLOBALS ###
NAMESPACE="llm-d"
STORAGE_SIZE="7Gi"
STORAGE_CLASS="efs-sc"
ACTION="install"
SCRIPT_DIR=""
REPO_ROOT=""
INSTALL_DIR=""
CHART_DIR=""
HF_NAME=""
HF_KEY=""
PROXY_UID=""
VALUES_FILE="values.yaml"
DEBUG=""
KUBERNETES_CONTEXT=""
SKIP_INFRA=false
INFRA_ONLY=false
DOWNLOAD_ONLY=false
DISABLE_METRICS=false
MONITORING_NAMESPACE="llm-d-monitoring"
DOWNLOAD_MODEL=""
DOWNLOAD_TIMEOUT="600"
GATEWAY_TYPE="istio"
HELM_RELEASE_NAME="llm-d"

# Minikube-specific flags & globals
USE_MINIKUBE=false
HOSTPATH_DIR=${HOSTPATH_DIR:="/mnt/data/llm-d-model-storage"}
MODEL_PV_NAME="model-hostpath-pv"
REDIS_PV_NAME="redis-hostpath-pv"
REDIS_PVC_NAME="redis-data-redis-master"

### HELP & LOGGING ###
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --auth-file PATH             Path to containers auth.json
  -z, --storage-size SIZE          Size of storage volume
  -c, --storage-class CLASS        Storage class to use (default: efs-sc)
  -n, --namespace NAME             K8s namespace (default: llm-d)
  -f, --values-file PATH           Path to Helm values.yaml file (default: values.yaml)
  -u, --uninstall                  Uninstall the llm-d components from the current cluster
  -d, --debug                      Add debug mode to the helm install
  -i, --skip-infra                 Skip the infrastructure components of the installation
  -e, --infra-only                 Only deploy infrastructure components
  -b, --download-pvc-only          Only download model to a PVC
  -m, --disable-metrics-collection Disable metrics collection (Prometheus will not be installed)
  -D, --download-model             Download the model to PVC from Hugging Face
  -t, --download-timeout           Timeout for model download job
  -k, --minikube                   Deploy on an existing minikube instance with hostPath storage
  -g, --context                    Supply a specific Kubernetes context
  -j, --gateway                    Select gateway type (istio, kgateway, gke-l7-rilb, gke-l7-regional-external-managed) (default: istio)
  -r, --release                    (Helm) Chart release name
  -h, --help                       Show this help and exit
EOF
}

# ANSI colour helpers and functions
COLOR_RESET=$'\e[0m'
COLOR_GREEN=$'\e[32m'
COLOR_YELLOW=$'\e[33m'
COLOR_RED=$'\e[31m'
COLOR_BLUE=$'\e[34m'

log_info() {
  echo "${COLOR_BLUE}ℹ️  $*${COLOR_RESET}"
}

log_success() {
  echo "${COLOR_GREEN}✅ $*${COLOR_RESET}"
}

log_error() {
  echo "${COLOR_RED}❌ $*${COLOR_RESET}" >&2
}

die()         { log_error "$*"; exit 1; }

### UTILITIES ###
check_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

check_dependencies() {
  # Verify mikefarah yq is installed
  if ! command -v yq &>/dev/null; then
    die "Required command not found: yq. Please install mikefarah yq from https://github.com/mikefarah/yq?tab=readme-ov-file#install"
  fi
  if ! yq --version 2>&1 | grep -q 'mikefarah'; then
    die "Detected yq is not mikefarah’s yq. Please install the required yq from https://github.com/mikefarah/yq?tab=readme-ov-file#install"
  fi

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
  uid_range=$($KCMD get namespace "${NAMESPACE}" -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' 2>/dev/null || true)
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
      -z|--storage-size)               STORAGE_SIZE="$2"; shift 2 ;;
      -c|--storage-class)              STORAGE_CLASS="$2"; shift 2 ;;
      -n|--namespace)                  NAMESPACE="$2"; shift 2 ;;
      -f|--values-file)                VALUES_FILE="$2"; shift 2 ;;
      -u|--uninstall)                  ACTION="uninstall"; shift ;;
      -d|--debug)                      DEBUG="--debug"; shift;;
      -i|--skip-infra)                 SKIP_INFRA=true; shift;;
      -e|--infra-only)                 INFRA_ONLY=true; shift;;
      -b|--download-pvc-only)          DOWNLOAD_ONLY=true; shift;;
      -m|--disable-metrics-collection) DISABLE_METRICS=true; shift;;
      -D|--download-model)             DOWNLOAD_MODEL="$2"; shift 2 ;;
      -t|--download-timeout)           DOWNLOAD_TIMEOUT="$2"; shift 2 ;;
      -k|--minikube)                   USE_MINIKUBE=true; shift ;;
      -g|--context)                    KUBERNETES_CONTEXT="$2"; shift 2 ;;
      -j|--gateway)                    GATEWAY_TYPE="$2"; shift 2 ;;
      -r|--release)                    HELM_RELEASE_NAME="$2"; shift 2 ;;
      -h|--help)                       print_help; exit 0 ;;
      *)                               die "Unknown option: $1" ;;
    esac
  done
}

# Helper to read a top-level value from override if present,
# otherwise fall back to chart’s values.yaml, and log the source
get_value() {
  local path="$1" src res
  if [[ "${VALUES_FILE}" != "values.yaml" ]] && \
     yq eval "has(${path})" - <"${SCRIPT_DIR}/${VALUES_FILE}" &>/dev/null; then
    src="$(realpath "${SCRIPT_DIR}/${VALUES_FILE}")"
  else
    src="${CHART_DIR}/values.yaml"
  fi
  >&2 log_info "🔹 Reading ${path} from ${src}"
  res=$(yq eval -r "${path}" "${src}")
  log_info "🔹 got ${res}"
  echo "${res}"
}

# Populate VALUES_PATH and VALUES_ARGS for any value overrides
resolve_values() {
  local base="${CHART_DIR}/values.yaml"
  [[ -f "${base}" ]] || die "Base values.yaml not found at ${base}"

  if [[ "${VALUES_FILE}" != "values.yaml" ]]; then
    local ov="${VALUES_FILE}"
    if   [[ -f "${ov}" ]]; then :;
    elif [[ -f "${SCRIPT_DIR}/${ov}" ]]; then ov="${SCRIPT_DIR}/${ov}";
    elif [[ -f "${REPO_ROOT}/${ov}" ]]; then    ov="${REPO_ROOT}/${ov}";
    else die "Override values file not found: ${ov}"; fi
    ov="$(realpath "${ov}")"
    local tmp; tmp=$(mktemp)
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' "${base}" "${ov}" >"${tmp}"
    VALUES_PATH="${tmp}"
    VALUES_ARGS=(--values "${base}" --values "${ov}")
  else
    # no override, only base
    VALUES_PATH="${base}"
    VALUES_ARGS=(--values "${base}")
  fi

  log_info "🔹 Using merged values: ${VALUES_PATH}"
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

  if [[ ! -z $KUBERNETES_CONTEXT ]]; then
    if [[ ! -f $KUBERNETES_CONTEXT ]]; then
      log_error "Error, the context file \"$KUBERNETES_CONTEXT\", passed via command-line option, does not exist!"
      exit 1
    fi
    KCMD="kubectl --kubeconfig $KUBERNETES_CONTEXT"
    HCMD="helm --kubeconfig $KUBERNETES_CONTEXT"

  else
    KCMD="kubectl"
    HCMD="helm"
  fi
}

validate_hf_token() {
  if [[ "$ACTION" == "install" ]]; then
    # HF_TOKEN from the env
    [[ -n "${HF_TOKEN:-}" ]] || die "HF_TOKEN not set; Run: export HF_TOKEN=<your_token>"
    log_success "HF_TOKEN validated"
  fi
}

validate_gateway_type() {
  case "${GATEWAY_TYPE}" in
    istio|kgateway|gke-l7-rilb|gke-l7-regional-external-managed)
      ;; # valid
    *)
      die "Invalid gateway type: ${GATEWAY_TYPE}. Supported types are: istio, kgateway, gke-l7-rilb, gke-l7-regional-external-managed."
      ;;
  esac
  log_success "Gateway type validated"
}

setup_minikube_storage() {
  log_info "📦 Setting up Minikube hostPath RWX Shared Storage..."
  log_info "🔄 Creating PV and PVC for llama model (PVC name: ${PVC_NAME})…"
  $KCMD apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${MODEL_PV_NAME}
  finalizers: []
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
  name: ${PVC_NAME}
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
  log_success "llama model PV and PVC (${PVC_NAME}) created."
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
    if [[ -n "${DOWNLOAD_MODEL}" ]]; then
      log_info "💾 Provisioning model storage…"

    if [[ "${DOWNLOAD_MODEL}" != */* ]]; then
        log_error "Error, --download-model ${DOWNLOAD_MODEL} is not in Hugging Face compliant format <org>/<repo>."
        exit 1
    fi

      HF_TOKEN_SECRET_NAME=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.name)
      HF_TOKEN_SECRET_KEY=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.key)

      DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH=$(realpath "${REPO_ROOT}/helpers/k8s/load-model-on-pvc-template.yaml")

      verify_env

      # If using Minikube, provision hostPath PV/PVC instead of default storage
      if [[ "${USE_MINIKUBE}" == "true" ]]; then
        log_info "⚙️ Minikube mode: setting up hostPath storage"
        setup_minikube_storage
      else
        # verify storage class exists
        log_info "🔍 Checking storage class \"${STORAGE_CLASS}\"..."
        if ! $KCMD get storageclass "${STORAGE_CLASS}" &>/dev/null; then
          log_error "Storage class \`${STORAGE_CLASS}\` not found. Please create it or pass --storage-class with a valid class."
          exit 1
        fi
        # apply the storage manifest
        eval "echo \"$(cat ${REPO_ROOT}/helpers/k8s/model-storage-rwx-pvc-template.yaml)\"" \
          | $KCMD apply -n "${NAMESPACE}" -f -
        log_success "PVC \`${PVC_NAME}\` created with storageClassName ${STORAGE_CLASS} and size ${STORAGE_SIZE}"
      fi

      log_info "🚀 Launching model download job..."
      if [[ "${YQ_TYPE}" == "go" ]]; then
        yq eval "
        (.spec.template.spec.containers[0].env[] | select(.name == \"MODEL_PATH\")).value = \"${MODEL_PATH}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_MODEL_ID\")).value = \"${DOWNLOAD_MODEL}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.name = \"${HF_TOKEN_SECRET_NAME}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.key = \"${HF_TOKEN_SECRET_KEY}\" |
        (.spec.template.spec.volumes[] | select(.name == \"model-cache\")).persistentVolumeClaim.claimName = \"${PVC_NAME}\"
        " "${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH}" | $KCMD apply -n ${NAMESPACE} -f -
      elif [[ "${YQ_TYPE}" == "py" ]]; then
        $KCMD apply -f ${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH} --dry-run=client -o yaml |
        yq -r | \
        jq \
        --arg modelPath "${MODEL_PATH}" \
        --arg hfModelId "${DOWNLOAD_MODEL}" \
        --arg hfTokenSecretName "${HF_TOKEN_SECRET_NAME}" \
        --arg hfTokenSecretKey "${HF_TOKEN_SECRET_KEY}" \
        --arg pvcName "${PVC_NAME}" \
        '
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "MODEL_PATH")).value = $modelPath |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_MODEL_ID")).value = $hfModelId |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.name = $hfTokenSecretName |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.key = $hfTokenSecretKey |
        (.spec.template.spec.volumes[] | select(.name == "model-cache")).persistentVolumeClaim.claimName = $pvcName
        ' | yq -y | $KCMD apply -n ${NAMESPACE} -f -
      else
        log_error "unrecognized yq distro -- error"
        exit 1
      fi

      log_info "⏳ Waiting 30 seconds pod to start running model download job ..."
      $KCMD wait --for=condition=Ready pod/$($KCMD get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name') --timeout=60s || {
        log_error "🙀 No pod picked up model download job";
        log_info "Please check your storageclass configuration for the \`download-model\` - if the PVC fails to spin the job will never get a pod"
        $KCMD logs job/download-model -n "${NAMESPACE}";
      }

      log_info "⏳ Waiting up to ${DOWNLOAD_TIMEOUT}s for model download job to complete; this may take a while depending on connection speed and model size..."
      $KCMD wait --for=condition=complete --timeout=${DOWNLOAD_TIMEOUT}s job/download-model -n "${NAMESPACE}" || {
        log_error "🙀 Model download job failed or timed out";
        JOB_POD=$($KCMD get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name')
        $KCMD logs pod/${JOB_POD} -n "${NAMESPACE}";
        exit 1;
      }

      log_success "Model downloaded"
    else
      log_info "⏭️ Model download to PVC skipped: \`--download-model\` arg not set, assuming PVC ${PVC_NAME} exists and contains model at path: \`${MODEL_PATH}\`."
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
    bash ../chart-dependencies/ci-deps.sh apply ${GATEWAY_TYPE}
    log_success "GAIE infra applied"
  fi

  if [[ "${INFRA_ONLY}" == "true" ]]; then
    log_info "Option \"-e/--infra-only\" specified, will end execution"
    return 0
  fi

  if $KCMD get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "🧹 Cleaning up existing monitoring namespace..."
    $KCMD delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found
  fi

  log_info "📦 Creating namespace ${NAMESPACE}..."
  $KCMD create namespace "${NAMESPACE}" --dry-run=client -o yaml | $KCMD apply -f -
  log_success "Namespace ready"

  cd "${CHART_DIR}"
  resolve_values

  log_info "🔐 Creating/updating HF token secret..."
  HF_NAME=$(yq -r .sampleApplication.model.auth.hfToken.name "${VALUES_PATH}")
  HF_KEY=$(yq -r .sampleApplication.model.auth.hfToken.key  "${VALUES_PATH}")
  $KCMD delete secret "${HF_NAME}" -n "${NAMESPACE}" --ignore-not-found
  $KCMD create secret generic "${HF_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-literal="${HF_KEY}=${HF_TOKEN}" \
    --dry-run=client -o yaml | $KCMD apply -n "${NAMESPACE}" -f -
  log_success "HF token secret created"

  # can be fetched non-invasily if using kgateway or not
  fetch_kgateway_proxy_uid

  log_info "📜 Applying modelservice CRD..."
  $KCMD apply -f crds/modelservice-crd.yaml
  log_success "ModelService CRD applied"

  create_pvc_and_download_model_if_needed
  if [[ "${DOWNLOAD_ONLY}" == "true" ]]; then
    log_info "Option \"-b/--download-pvc-only\" specified, will end execution"
    return 0
  fi

  $HCMD repo add bitnami  https://charts.bitnami.com/bitnami
  log_info "🛠️ Building Helm chart dependencies..."
  $HCMD dependency build .
  log_success "Dependencies built"

  if is_openshift; then
    BASE_OCP_DOMAIN=$($KCMD get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')
    OCP_DISABLE_INGRESS_ARGS=(
      --set ingress.enabled=false
    )
  else
    BASE_OCP_DOMAIN=""
    OCP_DISABLE_INGRESS_ARGS=()
  fi

  local metrics_enabled="true"
  if [[ "${DISABLE_METRICS}" == "true" ]]; then
    log_info "Metrics collection disabled by user request."
    metrics_enabled="false"
  else
    if is_openshift; then
      log_info "Using OpenShift's built-in monitoring stack."
      if ! check_openshift_monitoring; then
        log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled."
      fi
      # No Prometheus installation needed; metrics_enabled remains true for chart.
    elif [[ "${USE_MINIKUBE}" == "true" ]]; then
      log_info "🌱 Minikube detected; provisioning Prometheus/Grafana…"
      install_prometheus_grafana
    elif ! check_servicemonitor_crd; then
      log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found. Installing Prometheus stack."
      install_prometheus_grafana
    else
      log_info "Skipping Prometheus installation as ServiceMonitor CRD already exists."
    fi
    log_info "Metrics collection enabled"
  fi

  METRICS_ARGS=()
  if [[ "${metrics_enabled}" == "true" ]]; then
    METRICS_ARGS=(
      --set modelservice.metrics.enabled=true
    )
  else
    METRICS_ARGS=(
      --set modelservice.metrics.enabled=false
      --set modelservice.epp.metrics.enabled=false
      --set modelservice.vllm.metrics.enabled=false
    )
  fi

# Override model configuration if --download-model is specified
MODEL_OVERRIDE_ARGS=()
if [[ -n "${DOWNLOAD_MODEL}" ]]; then
  log_info "Overriding model configuration with user-specified model: ${DOWNLOAD_MODEL}"
  MODEL_OVERRIDE_ARGS=(
    --set sampleApplication.model.modelName="${DOWNLOAD_MODEL}"
    --set sampleApplication.model.modelArtifactURI="hf://${DOWNLOAD_MODEL}"
  )
  log_success "Model will be overridden: ${DOWNLOAD_MODEL}"
fi

  log_info "🚚 Deploying llm-d chart with ${VALUES_PATH}..."
  $HCMD upgrade -i ${HELM_RELEASE_NAME} . \
    ${DEBUG} \
    --namespace "${NAMESPACE}" \
    "${VALUES_ARGS[@]}" \
    "${OCP_DISABLE_INGRESS_ARGS[@]+"${OCP_DISABLE_INGRESS_ARGS[@]}"}" \
    --set gateway.gatewayClassName="${GATEWAY_TYPE}" \
    --set gateway.kGatewayParameters.proxyUID="${PROXY_UID}" \
    --set ingress.clusterRouterBase="${BASE_OCP_DOMAIN}" \
    "${METRICS_ARGS[@]}" \
    "${MODEL_OVERRIDE_ARGS[@]+"${MODEL_OVERRIDE_ARGS[@]}"}"
  log_success "$HELM_RELEASE_NAME deployed"

  post_install

  log_success "🎉 Installation complete."
}

# function called right before the installer exits
post_install() {
  # download-model pod deletion if it exists and in a succeeded phase
  local pod
  pod=$($KCMD get pods -n "${NAMESPACE}" \
    -l job-name=download-model \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$pod" ]]; then
    return
  fi
  local phase
  phase=$($KCMD get pod "$pod" -n "${NAMESPACE}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$phase" == "Succeeded" ]]; then
    $KCMD delete pod "$pod" -n "${NAMESPACE}" --ignore-not-found || true
    log_success "🧹 download-model pod deleted"
  else
    log_info "→ Pod ${pod} phase is ${phase}; skipping delete."
  fi
}

uninstall() {
  if [[ "${SKIP_INFRA}" == "false" ]]; then
    log_info "🗑️ Tearing down GAIE Kubernetes infrastructure…"
    bash ../chart-dependencies/ci-deps.sh delete ${GATEWAY_TYPE}
  fi
  MODEL_ARTIFACT_URI=$($KCMD get modelservice --ignore-not-found -n ${NAMESPACE} -o yaml | yq '.items[].spec.modelArtifacts.uri')
  PROTOCOL="${MODEL_ARTIFACT_URI%%://*}"
  if [[ "${PROTOCOL}" == "pvc" ]]; then
    INFERENCING_DEPLOYMENT=$($KCMD get deployments --ignore-not-found  -n ${NAMESPACE} -l llm-d.ai/inferenceServing=true | tail -n 1 | awk '{print $1}')
    PVC_NAME=$( $KCMD get deployments --ignore-not-found  $INFERENCING_DEPLOYMENT -n ${NAMESPACE} -o yaml | yq '.spec.template.spec.volumes[] | select(has("persistentVolumeClaim"))' | yq .claimName)
    PV_NAME=$($KCMD get pvc ${PVC_NAME} --ignore-not-found  -n ${NAMESPACE} -o yaml | yq .spec.volumeName)
    $KCMD delete job download-model --ignore-not-found || true
  fi
  log_info "🗑️ Uninstalling llm-d chart..."
  $HCMD uninstall ${HELM_RELEASE_NAME} --ignore-not-found --namespace "${NAMESPACE}" || true

  log_info "🗑️ Deleting namespace ${NAMESPACE}..."
  $KCMD delete namespace "${NAMESPACE}" --ignore-not-found || true

  log_info "🗑️ Deleting monitoring namespace..."
  $KCMD delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found || true

  # Check if we installed the Prometheus stack and delete the ServiceMonitor CRD if we did
  if $HCMD list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus" 2>/dev/null; then
    log_info "🗑️ Deleting ServiceMonitor CRD..."
    $KCMD delete crd servicemonitors.monitoring.coreos.com --ignore-not-found || true
  fi

  if [[ "${USE_MINIKUBE}" == "true" || "$(kubectl config current-context 2>/dev/null)" == "minikube" ]]; then
    log_info "🗑️ Minikube context found; deleting hostPath PV (${MODEL_PV_NAME})"
    kubectl delete pv "${MODEL_PV_NAME}" --ignore-not-found || true
  fi

  log_info "🗑️ Deleting ClusterRoleBinding llm-d"
  $KCMD delete clusterrolebinding -l app.kubernetes.io/instance=llm-d

  log_success "💀 Uninstallation complete"
}

check_servicemonitor_crd() {
  log_info "🔍 Checking for ServiceMonitor CRD (monitoring.coreos.com)..."
  if ! $KCMD get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found"
    return 1
  fi

  API_VERSION=$($KCMD get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.spec.versions[?(@.served)].name}' 2>/dev/null || echo "")

  if [[ -z "$API_VERSION" ]]; then
    log_info "⚠️ Could not determine ServiceMonitor CRD API version"
    return 1
  fi

  if [[ "$API_VERSION" == "v1" ]]; then
    log_success "ServiceMonitor CRD (monitoring.coreos.com/v1) found"
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
  if $KCMD get configmap cluster-monitoring-config -n openshift-monitoring -o yaml 2>/dev/null | grep -q "enableUserWorkload: true"; then
    log_success "✅ OpenShift user workload monitoring is properly configured"
    return 0
  fi

  log_info "⚠️ OpenShift user workload monitoring is not enabled"
  log_info "ℹ️ Enabling user workload monitoring allows metrics collection for the llm-d chart."

  local monitoring_yaml=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF
)

  # Prompt the user
  log_info "📜 The following ConfigMap will be applied to enable user workload monitoring:"
  echo "$monitoring_yaml"
  read -p "Would you like to apply this ConfigMap to enable user workload monitoring? (y/N): " response
  case "$response" in
    [yY][eE][sS]|[yY])
      log_info "🚀 Applying ConfigMap to enable user workload monitoring..."
      echo "$monitoring_yaml" | oc create -f -
      if [[ $? -eq 0 ]]; then
        log_success "✅ OpenShift user workload monitoring enabled"
        return 0
      else
        log_error "❌ Failed to apply ConfigMap. Metrics collection may not work."
        return 1
      fi
      ;;
    *)
      log_info "⚠️ User chose not to enable user workload monitoring."
      log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled."
      return 1
      ;;
  esac
}

is_openshift() {
  # Check for OpenShift-specific resources
  if $KCMD get clusterversion &>/dev/null; then
    return 0
  fi
  return 1
}

install_prometheus_grafana() {
  log_info "🌱 Provisioning Prometheus operator…"

  if ! $KCMD get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "📦 Creating monitoring namespace..."
    $KCMD create namespace "${MONITORING_NAMESPACE}"
  else
    log_info "📦 Monitoring namespace already exists"
  fi

  if ! $HCMD repo list 2>/dev/null | grep -q "prometheus-community"; then
    log_info "📚 Adding prometheus-community helm repo..."
    $HCMD repo add prometheus-community https://prometheus-community.github.io/helm-charts
    $HCMD repo update
  fi

  if $HCMD list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus"; then
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
    maximumStartupDurationSeconds: 300
EOF

  $HCMD install prometheus prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NAMESPACE}" \
    -f /tmp/prometheus-values.yaml \
    1>/dev/null

  rm -f /tmp/prometheus-values.yaml

  log_info "⏳ Waiting for Prometheus stack pods to be ready..."
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "${MONITORING_NAMESPACE}" --timeout=300s || true
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n "${MONITORING_NAMESPACE}" --timeout=300s || true

  log_success "🚀 Prometheus and Grafana installed."
}

main() {
  parse_args "$@"

  setup_env
  check_dependencies

  # Check cluster reachability as a pre-requisite
  check_cluster_reachability

  validate_hf_token
  validate_gateway_type

  if [[ "$ACTION" == "install" ]]; then
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
