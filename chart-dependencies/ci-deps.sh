#!/bin/bash
# -*- indent-tabs-mode: nil; tab-width: 2; sh-indentation: 2; -*-

# This is a dependency for the CI job .github/workflows/test.yaml
# Prep installation of dependencies for GAIE

set +x
set -e
set -o pipefail

if [ -z "$(command -v kubectl)" ] || [ -z "$(command -v helm)" ]; then
    echo "This script depends on \`kubectl\` and \`helm\`. Please install them."
    exit 1
fi

CWD=$( dirname -- "$( readlink -f -- "$0"; )"; )

## Populate manifests
MODE=${1:-apply} # allowed values "apply" or "delete"

if [[ "$MODE" == "apply" ]]; then
    LOG_ACTION_NAME="Installing"
else
    LOG_ACTION_NAME="Deleting"
fi

### Base CRDs
echo -e "\e[32m📜 Base CRDs: ${LOG_ACTION_NAME}...\e[0m"
kubectl $MODE -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gateway-api?ref=dev || true

### GAIE CRDs
echo -e "\e[32m🚪 GAIE CRDs: ${LOG_ACTION_NAME}...\e[0m"
kubectl $MODE -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gie?ref=dev || true

### Install Gateway provider
backend=$(helm show values $CWD/../charts/llm-d --jsonpath '{.gateway.gatewayClassName}')

echo -e "\e[32m🎒 Gateway provider \e[0m '\e[34m$backend\e[0m'\e[32m: ${LOG_ACTION_NAME}...\e[0m"

$CWD/$backend/install.sh $MODE
