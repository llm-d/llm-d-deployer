REPO_ROOT=$(git rev-parse --show-toplevel)
NAMESPACE=${1:-llm-d}

# Read the values.yaml file to get configuration
VALUES_FILE="${REPO_ROOT}/charts/llm-d/values.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: values.yaml file not found at $VALUES_FILE"
    exit 1
fi

# Extract model name from values.yaml
MODEL_NAME=$(grep "modelName:" "$VALUES_FILE" | awk '{print $2}' | tr -d '"')
if [ -z "$MODEL_NAME" ]; then
    echo "Warning: Could not find modelName in values.yaml, using default"
    MODEL_NAME="Llama-3.2-3B-Instruct"
fi

MODEL_ID=${2:-${MODEL_NAME}}

POD_IP=$(kubectl get pods -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' | grep decode | awk '{print $2}')
echo "Testing GET /v1/models to ${NAMESPACE} at Pod IP ${POD_IP}"
RANDOM=$(shuf -i 1-10000 -n 1)
kubectl run --rm -i curl-${RANDOM} --image=curlimages/curl --restart=Never -- \
    curl -X GET \
    "http://${POD_IP}:8000/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'

echo "Testing POST /v1/chat/completions to ${NAMESPACE} at Pod IP ${POD_IP}"
RANDOM=$(shuf -i 1-10000 -n 1)
kubectl run --rm -i curl-${RANDOM} --image=curlimages/curl --restart=Never -- \
  curl -X POST \
  "http://${POD_IP}:8000/v1/chat/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'${MODEL_ID}'",
    "messages": [{"content": "Who are you?", "role": "user"}],
    "stream": false
  }'

GATEWAY_ADDRESS=$(kubectl get gateway -n ${NAMESPACE} | tail -n 1 | awk '{print $3}')
echo "Testing GET /v1/models to ${NAMESPACE} at Gateway IP ${GATEWAY_ADDRESS}"
RANDOM=$(shuf -i 1-10000 -n 1)
kubectl run --rm -i curl-${RANDOM} --image=curlimages/curl --restart=Never -- \
    curl -X GET \
    "http://${GATEWAY_ADDRESS}/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'

echo "Testing POST /v1/chat/completions to ${NAMESPACE} at Gateway IP ${GATEWAY_ADDRESS}"
RANDOM=$(shuf -i 1-10000 -n 1)
kubectl run --rm -i curl-${RANDOM} --image=curlimages/curl --restart=Never -- \
  curl -X POST \
  "http://${GATEWAY_ADDRESS}/v1/chat/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'${MODEL_ID}'",
    "messages": [{"content": "Who are you?", "role": "user"}],
    "stream": false
  }'
