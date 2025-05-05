REPO_ROOT=$(realpath $(git rev-parse --show-toplevel))
kubectl create -f ${REPO_ROOT}/ms-v2-hack/inferencepool.yaml
