#!/bin/bash
# -*- indent-tabs-mode: nil; tab-width: 2; sh-indentation: 2; -*-

# This is a dependency for the CI job .github/workflows/test.yaml
# Prep installation of dependencies for GAIE

set -x
set -e
set -o pipefail

if [ -z "$(command -v git)" ] || [ -z "$(command -v kubectl)" ] || [ -z "$(command -v helm)" ]; then
    echo "This script depends on \`git\`, \`kubectl\` and \`helm\`. Please install them."
    exit 1
fi

if [ "chart-dependencies" != "${PWD/*\//}" ]; then
    echo "Script must be invoked within this directory"
    exit 1
fi

## Populate manifests

#### GAIE manifests

if [ -d "gateway-api-inference-extension" ]; then # idempotency
    rm -rf ./gateway-api-inference-extension
fi

git clone --filter=blob:none --no-checkout https://github.com/neuralmagic/gateway-api-inference-extension.git
pushd gateway-api-inference-extension

git sparse-checkout init --cone
git checkout dev

git sparse-checkout set config/crd

cp -r config/crd ../00-base-crds

git sparse-checkout set deploy/components

cp -r deploy/components/crds-kgateway ../00-base-crds

popd
rm -rf gateway-api-inference-extension

#### Apply manifests

kubectl kustomize 00-base-crds --enable-helm=true  | kubectl apply -f -
01-kgateway-control-plane/helm-install.sh
