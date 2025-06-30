#!/usr/bin/env bash

MODE=${1:-apply}

if [[ "$MODE" == "apply" ]]; then
  helm upgrade -i \
    --namespace kgateway-system \
    --create-namespace \
    --version v2.0.3 \
    kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds

  helm upgrade -i \
    --namespace kgateway-system \
    --create-namespace \
    --version v2.0.3 \
    --set inferenceExtension.enabled=true \
    --set securityContext.allowPrivilegeEscalation=false \
    --set securityContext.capabilities.drop={ALL} \
    --set podSecurityContext.seccompProfile.type=RuntimeDefault \
    --set podSecurityContext.runAsNonRoot=true \
    kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
else
  helm uninstall kgateway --ignore-not-found  --namespace kgateway-system || true
  helm uninstall kgateway-crds --ignore-not-found --namespace kgateway-system || true
  helm template kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version v2.0.3 | kubectl delete -f - --ignore-not-found
fi
