helm upgrade -i \
  --namespace kgateway-system \
  --create-namespace \
  --version v2.0.0 \
  --set inferenceExtension.enabled=true \
  --set securityContext.allowPrivilegeEscalation=false \
  --set securityContext.capabilities.drop={ALL} \
  --set podSecurityContext.seccompProfile.type=RuntimeDefault \
  --set podSecurityContext.runAsNonRoot=true \
  kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
