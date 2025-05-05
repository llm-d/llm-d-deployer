# Model service v2 hack

## Install

```bash
export REPO_ROOT=$(realpath $(git rev-parse --show-toplevel))
"${REPO_ROOT}/ms-v2-hack/setup.sh"
HF_TOKEN=$(HFTOKEN) ./llmd-installer.sh --namespace e2e-helm --skip-infra
```

## Uninstall

```bash
HF_TOKEN=$(HFTOKEN) ./llmd-installer.sh --namespace e2e-helm --skip-infra --uninstall
```
