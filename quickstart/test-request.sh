#!/bin/bash
# -----------------------------------------------------------------------------
# test-request.sh
#
# Description:
#   Quick smoke tests against your llm-d deployment:
#     1) GET /v1/models on the decode pod
#     2) POST /v1/completions on the decode pod
#     3) GET /v1/models via the gateway
#     4) POST /v1/completions via the gateway
#
# -----------------------------------------------------------------------------

set -euo pipefail

if ! command -v kubectl &>/dev/null; then
  echo "Error: 'kubectl' not found in PATH." >&2
  exit 1
fi

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Quick smoke tests against your llm-d deployment.

Options:
  -n, --namespace NAMESPACE   Kubernetes namespace to use (default: llm-d)
  -m, --model MODEL_ID        Model to query (optional: served model will be discovered from model listing)
  -k, --minikube              Run only Minikube DNS gateway tests
  -h, --help                  Show this help message and exit
EOF
  exit 0
}

# ── Parse flags ───────────────────────────────────────────────────────────────
NAMESPACE="llm-d"
CLI_MODEL_ID=""
USE_MINIKUBE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -m|--model)
      CLI_MODEL_ID="$2"
      shift 2
      ;;
    -k|--minikube)
      USE_MINIKUBE=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

MODEL_ID="${CLI_MODEL_ID:-}"

echo "Namespace: $NAMESPACE"
if [[ -n "$MODEL_ID" ]]; then
  echo "Model ID:  $MODEL_ID"
else
  echo "Model ID:  none; will be discover from first entry in /v1/models"
fi
echo

# ── Helper to generate a unique suffix ───────────────────────────────────────
gen_id() { echo $(( RANDOM % 10000 + 1 )); }

# ── Extract all model IDs from JSON blob (for display on error) ──────────────
extract_models() {
  printf '%s' "$1" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
}

# ── Grab the FIRST model ID from JSON blob ───────────────────────────────────
infer_first_model() {
  printf '%s' "$1" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4
}

validation() {
  # Discover the decode pod IP
  POD_IP=$(kubectl get pods -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' \
    | grep decode | awk '{print $2}' | head -1)

  if [[ -z "$POD_IP" ]]; then
      echo "Error: no decode pod found in namespace $NAMESPACE"
      exit 1
  fi

  # ── 1) GET /v1/models on decode pod ─────────────────────────────────────────
  echo "1 -> Fetching available models from the decode pod at ${POD_IP}…"
  ID=$(gen_id)
  LIST_JSON=$(kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS http://${POD_IP}:8000/v1/models \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json')
  echo "$LIST_JSON"
  echo

  # infer or validate
  if [[ -z "$MODEL_ID" ]]; then
    MODEL_ID=$(infer_first_model "$LIST_JSON")
    echo "Discovered model to use: $MODEL_ID"
  else
    if ! grep -q "\"id\":\"$MODEL_ID\"" <<<"$LIST_JSON"; then
      echo "Error: requested model '$MODEL_ID' not found in available models:"
      extract_models "$LIST_JSON" | head -n1
      exit 1
    fi
  fi
  echo

  # ── 2) POST /v1/completions on decode pod ──────────────────────────────────
  echo "2 -> Sending a completion request to the decode pod at ${POD_IP}…"
  ID=$(gen_id)
  kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS -X POST http://${POD_IP}:8000/v1/completions \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
        "model":"'"$MODEL_ID"'",
        "prompt":"Who are you?"
      }'
  echo

  # 3) GET /v1/models via the gateway
  GATEWAY_ADDR=$(kubectl get gateway -n "$NAMESPACE" | tail -n1 | awk '{print $3}')
  echo "3 -> Fetching available models via the gateway at ${GATEWAY_ADDR}…"
  ID=$(gen_id)
  GW_JSON=$(kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS http://${GATEWAY_ADDR}/v1/models \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json')
  echo "$GW_JSON"
  echo

  if ! grep -q "\"id\":\"$MODEL_ID\"" <<<"$GW_JSON"; then
    echo "Error: model '$MODEL_ID' not available via gateway:"
    extract_models "$GW_JSON"
    exit 1
  fi
  echo

  # ── 4) POST /v1/completions via gateway ────────────────────────────────────
  echo "4 -> Sending a completion request via the gateway at ${GATEWAY_ADDR} with model '${MODEL_ID}'…"
  ID=$(gen_id)
  kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS -X POST http://${GATEWAY_ADDR}/v1/completions \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
        "model":"'"$MODEL_ID"'",
        "prompt":"Who are you?"
      }'
  echo
}

# ── Minikube gateway validation ───────────────────────────────────────────────
minikube_validation() {
  SVC_HOST="llm-d-inference-gateway-istio.${NAMESPACE}.svc.cluster.local:80"
  echo "Minikube validation: hitting gateway DNS at ${SVC_HOST}"

  # 1) GET /v1/models via DNS gateway
  echo "1 -> GET /v1/models via DNS at ${SVC_HOST}…"
  ID=$(gen_id)
  LIST_JSON=$(kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS http://${SVC_HOST}/v1/models \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json')
  echo "$LIST_JSON"
  echo

  # Discover or validate
  if [[ -z "$MODEL_ID" ]]; then
    MODEL_ID=$(infer_first_model "$LIST_JSON")
    echo "Inferred model to use: $MODEL_ID"
  else
    if ! grep -q "\"id\":\"$MODEL_ID\"" <<<"$LIST_JSON"; then
      echo "Error: requested model '$MODEL_ID' not found in available models:"
      extract_models "$LIST_JSON"
      exit 1
    fi
  fi
  echo

  # 2) POST /v1/completions via DNS gateway
  echo "2 -> POST /v1/completions via DNS at ${SVC_HOST} with model '${MODEL_ID}'…"
  ID=$(gen_id)
  kubectl run --rm -i curl-"$ID" \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS -X POST http://${SVC_HOST}/v1/completions \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
        "model":"'"$MODEL_ID"'",
        "prompt":"You are a helpful AI assistant."
      }'
  echo
}

# ── Main ───────────────────────────────────────────
if [[ "$USE_MINIKUBE" == true ]]; then
  minikube_validation
else
  validation
fi

echo "All tests complete."
