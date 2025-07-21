
# ⚠️ Deprecation Notice: `llm-d-deployer`

**This repository is no longer actively maintained.**

The `llm-d-deployer` repository previously hosted monolithic Helm charts for installing components of the `llm-d` ecosystem. As of 25-07-2025, we are deprecating this repository in favor of a more modular and composable approach provided by [`llm-d-infra`](https://github.com/llm-d-incubation/llm-d-infra).

## ✅ Migration to `llm-d-infra`

The [`llm-d-infra`](https://github.com/llm-d-incubation/llm-d-infra) repository contains pre-curated deployment examples of the `llm-d` ecosystem using [Helmfile](https://github.com/helmfile/helmfile). It enables flexible configuration and composition of the following:

- Similar quickstart pattern to deployer for creating namespace, deploying metrics infrastructure, creating secret for the `HF_TOKEN`, etc.
  - See the [installer script](https://github.com/llm-d-incubation/llm-d-infra/blob/main/quickstart/llmd-infra-installer.sh) for more information.
- Gateway Deployment and configurations are based on the install of the `llm-d-infra` charts
- Installation of the new [modelservice helm charts](https://github.com/llm-d-incubation/llm-d-modelservice)
  - The controller pattern for `modelservice` was deprecated, same with the idea of `baseConfig` presets and `sampleApplication`s. Instead the modelservice charts focus on clearer deployments with modularity, allowing people to opt in or out of all components (`epp`, P/D `deployment`s or `leaderWorkerSets`, `inferencepool`, `inferencemodel`, etc.). For more information check out their [getting-started docs](https://github.com/llm-d-incubation/llm-d-modelservice?tab=readme-ov-file#getting-started)
- Compatibility with [upstream GIE charts](https://github.com/kubernetes-sigs/gateway-api-inference-extension)
  - Most of our examples feature this, but the [simple example](https://github.com/llm-d-incubation/llm-d-infra/tree/main/quickstart/examples/simple) would be the easiest place to start to experience the composability with upstream GIE charts

You are encouraged to migrate any existing deployments to the examples provided in `llm-d-infra`, or use it as a reference to build your own Helmfile stacks.

## 📦 What Happens to This Repo?

- The charts in this repo are **no longer updated**.
- Issues and PRs will be closed with a deprecation notice.
- Historical references are preserved, but users should **not use this repo for new deployments**.
- The repo contents will remain if people want to use the existing monolithic installs.
  - For information on this refer to our old [docs](./REPO_DOCS.md)

## 🛠️ Need Help Migrating?

If you're currently using the `llm-d-deployer` Helm charts and need help migrating to `llm-d-infra`, feel free to reach out via slack in the [#sig-installation channel](https://llm-d.slack.com/archives/C08SLBGKBEZ) or file an issue in the [`llm-d-infra`](https://github.com/llm-d-incubation/llm-d-infra) repo.

---

Thanks for supporting the `llm-d` project!
