#!/bin/bash

TAG=1.26-alpha.9befed2f1439d883120f8de70fd70d84ca0ebc3d
HUB=gcr.io/istio-testing

if [[ "$MODE" == "apply" ]]; then
    helm upgrade -i istio-base oci://$HUB/charts/base --version $TAG -n istio-system --create-namespace
    helm upgrade -i istiod oci://$HUB/charts/istiod --version $TAG -n istio-system --set tag=$TAG --set hub=$HUB --wait
else
  helm uninstall istiod --namespace istio-system
  helm uninstall istio-base --namespace istio-system
  helm template istio-base oci://$HUB/charts/base --version $TAG -n istio-system | kubectl delete -f - --ignore-not-found
fi
