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

### Clone and apply CRDs from GitHub (SSH or HTTPS fallback)
apply_crds_from_repo() {
  local BRANCH="dev"
  local REPO_SSH="git@github.com:llm-d/llm-d-inference-scheduler.git"
  local REPO_HTTPS="https://github.com/llm-d/llm-d-inference-scheduler.git"
  local TMP_DIR=$(mktemp -d)
  local REPO_USED=""

  echo -e "\e[36m🔍 Cloning CRD repo (branch: $BRANCH)...\e[0m"

  if git clone --depth 1 --branch "$BRANCH" "$REPO_SSH" "$TMP_DIR" 2>/dev/null; then
    REPO_USED="SSH"
  elif git clone --depth 1 --branch "$BRANCH" "$REPO_HTTPS" "$TMP_DIR"; then
    REPO_USED="HTTPS"
  else
    echo -e "\e[31m❌ Failed to clone repository using both SSH and HTTPS.\e[0m"
    exit 1
  fi

  echo -e "\e[32m✅ Repo cloned via $REPO_USED\e[0m"

  echo -e "\e[32m📜 Base CRDs: ${LOG_ACTION_NAME}...\e[0m"
  kubectl $MODE -k "$TMP_DIR/deploy/components/crds-gateway-api" || true

  echo -e "\e[32m🚪 GAIE CRDs: ${LOG_ACTION_NAME}...\e[0m"
  kubectl $MODE -k "$TMP_DIR/deploy/components/crds-gie" || true

  rm -rf "$TMP_DIR"
}

# Run CRD installer
apply_crds_from_repo

### Install Gateway provider
backend=$(helm show values $CWD/../charts/llm-d --jsonpath '{.gateway.gatewayClassName}')

echo -e "\e[32m🎒 Gateway provider \e[0m '\e[34m$backend\e[0m'\e[32m: ${LOG_ACTION_NAME}...\e[0m"

$CWD/$backend/install.sh $MODE
