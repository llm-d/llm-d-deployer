REPO_ROOT=$(realpath $(git rev-parse --show-toplevel))
kubectl create namespace e2e-helm --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=e2e-helm
kustomize build ${REPO_ROOT}/ms-v2-hack | oc apply -f -
