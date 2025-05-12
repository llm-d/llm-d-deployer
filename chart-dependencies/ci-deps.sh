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

### Base CRDs
echo -e "\e[32m📜 Applying base CRDs\e[0m"
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gateway-api?ref=dev

### GAIE CRDs
echo -e "\e[32m🚪 Applying GAIE CRDs\e[0m"
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gie?ref=dev

### Install Gateway provider
backend=$(helm show values $CWD/../charts/llm-d --jsonpath '{.gateway.gatewayClassName}')

echo -e "\e[32m🎒 Installing Gateway provider:\e[0m '\e[34m$backend\e[0m'"
$CWD/$backend/install.sh
