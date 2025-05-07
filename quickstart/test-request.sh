NAMESPACE=${1:-llm-d}
MODEL_ID=${2:-Llama-3.2-3B-Instruct}

POD_IP=$(kubectl get pods -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' | grep decode | awk '{print $2}')
echo "Testing request to ${NAMESPACE} at Pod IP ${POD_IP}"

kubectl run --rm -i curl-temp --image=curlimages/curl --restart=Never -- \
    curl -X GET \
    "http://${POD_IP}:8000/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'


kubectl run --rm -i curl-temp --image=curlimages/curl --restart=Never -- \
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
echo "Testing request to ${NAMESPACE} at Gateway IP ${GATEWAY_ADDRESS}"

kubectl run --rm -i curl-temp --image=curlimages/curl --restart=Never -- \
    curl -X GET \
    "http://${GATEWAY_ADDRESS}/v1/models" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json'

kubectl run --rm -i curl-temp --image=curlimages/curl --restart=Never -- \
  curl -X POST \
  "http://${GATEWAY_ADDRESS}/v1/chat/completions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "'${MODEL_ID}'",
    "messages": [{"content": "Who are you?", "role": "user"}],
    "stream": false
  }'
