# 📝 llm-d Release Note Generator

This tool generates well-formatted release notes for the `llm-d` project using a `release.yaml` descriptor and data pulled from GitHub. It is intended to assist release managers in crafting consistent, accurate, and informative release notes across multiple components.

---

## 🚀 How It Works

You write a `release.yaml` file that defines:

- The overall project version
- The Helm chart version
- A list of components with:
  - `name`
  - `repo` (GitHub repo)
  - `version` (image tag/Git tag)
  - `old_version` (optional — used for diffs)

The script will:

1. Generate a component summary table.
2. For each component:
   - If an `old_version` is provided and differs from `version`, it generates a GitHub **changelog diff link**
   - It retrieves the Git **commit SHA** for the version tag
   - It finds the **pull request** that introduced the commit
   - It fetches the **GitHub Actions check runs** on that PR's last commit and includes them in the notes

The final output is written to a Markdown file named based on the release version (e.g. `release-llm-d-1.1.0.md`).

---

## ✍️ Creating the Release YAML File

Here’s an example structure for your `release.yaml`:

```yaml
project_version: llm-d-1.1.0
chart_version: 1.1.0
release_date: 2025-07-17
components:
  - name: epp
    version: v0.1.0
    old_version: v0.0.9
    repo: llm-d/llm-d-inference-scheduler
  - name: modelservice
    version: v0.0.15
    repo: llm-d/llm-d-model-service
  ...
```
