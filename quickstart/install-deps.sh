#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

# Detect package manager
if command -v apt &> /dev/null; then
  PKG_INSTALL="sudo apt update && sudo apt install -y"
elif command -v dnf &> /dev/null; then
  PKG_INSTALL="sudo dnf install -y"
elif command -v yum &> /dev/null; then
  PKG_INSTALL="sudo yum install -y"
else
  echo "Unsupported Linux distribution (no apt, dnf, or yum found)."
  exit 1
fi

# Install base packages
$PKG_INSTALL git jq make curl tar wget

# Install yq (v4+)
if ! command -v yq &> /dev/null; then
  echo "Installing yq..."
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod +x /usr/local/bin/yq
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

# Install helm
if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install kustomize
if ! command -v kustomize &> /dev/null; then
  echo "Installing Kustomize..."
  KUSTOMIZE_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq -r '.tag_name')
  curl -sLo kustomize.tar.gz "https://github.com/kubernetes-sigs/kustomize/releases/download/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION#kustomize/}_linux_amd64.tar.gz"
  tar -xzf kustomize.tar.gz
  sudo mv kustomize /usr/local/bin/
  rm kustomize.tar.gz
fi

echo "All tools installed successfully."
