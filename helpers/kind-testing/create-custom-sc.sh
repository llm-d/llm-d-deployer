export defaultScProvisioner=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].provisioner}')
if [[ -z "$defaultScProvisioner" ]]; then
    echo "No default storage class found or it has no provisioner. Exiting early because the test using the custom Storage Class will likely fail. Use a cluster that has a default storage class."
    exit 1
fi
echo "[INFO] defaultScProvisioner=$defaultScProvisioner"

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: custom-sc
# same provisioner as the one used by the default storage class on the cluster
provisioner: $defaultScProvisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl get storageclass custom-sc -o yaml
