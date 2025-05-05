#!/bin/zsh
export SERVICE_ACCOUNT_NAMES="endpoint-picker,llm-d,default"
export SECRET_NAME="greg-pull-secret"
export NAMESPACES="greg-test-deploy,"

NAMESPACES_ARRAY=(${(s:,:)NAMESPACES})

for NAMESPACE in $NAMESPACES_ARRAY; do
  oc create secret generic "${SECRET_NAME}" \
    --from-file=.dockerconfigjson=$HOME/.config/containers/auth.json \
    --type=kubernetes.io/dockerconfigjson \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | oc apply -f -
done

SERVICE_ACCOUNT_ARRAY=(${(s:,:)SERVICE_ACCOUNT_NAMES})

for SERVICE_ACCOUNT_NAME in $SERVICE_ACCOUNT_ARRAY; do
  oc secrets link "${SERVICE_ACCOUNT_NAME}" "${SECRET_NAME}" -n "${NAMESPACE}" --for=pull
done
