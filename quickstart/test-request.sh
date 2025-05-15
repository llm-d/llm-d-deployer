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
# Usage: test-request.sh [OPTIONS]
#
# Options:
#   -n, --namespace NAMESPACE   Kubernetes namespace to use (default: llm-d)
#   -m, --model MODEL_ID        Model to query (env MODEL_ID → values.yaml)
#   -h, --help                  Show this help message and exit
# -----------------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Quick smoke tests against your llm-d deployment.

Options:
  -n, --namespace NAMESPACE   Kubernetes namespace to use (default: llm-d)
  -m, --model MODEL_ID        Model to query (env MODEL_ID → values.yaml)
  -h, --help                  Show this help message and exit
EOF
  exit 0
}

# ── Parse flags ───────────────────────────────────────────────────────────────
NAMESPACE="llm-d"
CLI_MODEL_ID=""

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
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# ── Determine MODEL_ID ───────────────────────────────────────────────────────
if [[ -n "$CLI_MODEL_ID" ]]; then
  MODEL_ID="$CLI_MODEL_ID"
elif [[ -n "${MODEL_ID-}" ]]; then
  MODEL_ID="$MODEL_ID"
else
REPO_ROOT=$(git rev-parse --show-toplevel)
VALUES_FILE="${REPO_ROOT}/charts/llm-d/values.yaml"
if [[ ! -f "$VALUES_FILE" ]]; then
    echo "Warn: values.yaml not found at $VALUES_FILE"
    exit 1
fi
  MODEL_ID=$(grep '^modelName:' "$VALUES_FILE" | awk '{print $2}' | tr -d '"')
  if [[ -z "$MODEL_ID" ]]; then
    echo "Warning: no modelName in values.yaml; using default"
    MODEL_ID="meta-llama/Llama-3.2-3B-Instruct"
fi
fi

echo "Namespace: $NAMESPACE"
echo "Model ID:  $MODEL_ID"
echo

# ── Helper to generate a unique suffix ───────────────────────────────────────
gen_id() { echo $(( RANDOM % 10000 + 1 )); }

# ── Discover the decode pod IP ───────────────────────────────────────────────
POD_IP=$(kubectl get pods -n "$NAMESPACE" \
         -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' \
       | grep decode | awk '{print $2}')

if [[ -z "$POD_IP" ]]; then
    echo "Error: no decode pod found in namespace $NAMESPACE"
    exit 1
fi

# ── 1) GET /v1/models on decode pod ─────────────────────────────────────────
echo "1 -> Fetching available models from the decode pod at ${POD_IP}…"
ID=$(gen_id)
kubectl run --rm -i curl-"$ID" \
  --image=curlimages/curl --restart=Never -- \
  curl -sS -X GET "http://${POD_IP}:8000/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'
echo

# ── 2) POST /v1/completions on decode pod ──────────────────────────────────
echo "2 -> Sending a completion request to the decode pod at ${POD_IP}…"
ID=$(gen_id)
kubectl run --rm -i curl-"$ID" \
  --image=curlimages/curl --restart=Never -- \
  curl -sS -X POST "http://${POD_IP}:8000/v1/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model":"'"$MODEL_ID"'",
    "prompt":"Who are you?"
  }'
echo

# ── Discover the gateway address ────────────────────────────────────────────
GATEWAY_ADDR=$(kubectl get gateway -n "$NAMESPACE" | tail -n1 | awk '{print $3}')

# ── 3) GET /v1/models via gateway ───────────────────────────────────────────
echo "3 -> Fetching available models via the gateway at ${GATEWAY_ADDR}…"
ID=$(gen_id)
kubectl run --rm -i curl-"$ID" \
  --image=curlimages/curl --restart=Never -- \
  curl -sS -X GET "http://${GATEWAY_ADDR}/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'
echo

# ── 4) POST /v1/completions via gateway ────────────────────────────────────
echo "4 -> Sending a completion request via the gateway at ${GATEWAY_ADDR}…"
ID=$(gen_id)
kubectl run --rm -i curl-"$ID" \
  --image=curlimages/curl --restart=Never -- \
  curl -sS -X POST "http://${GATEWAY_ADDR}/v1/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model":"'"$MODEL_ID"'",
    "prompt":"Who are you?"
  }'
echo

echo "✅ All tests complete."
