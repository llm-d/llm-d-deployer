---
name: Pull request
about: Create a pull request
---

# Pull Request Template

## Description

Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context. List any dependencies that are required for this change.

Fixes # (issue)

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

## How Has This Been Tested?

Please describe the tests that you ran to verify your changes. Provide instructions so we can reproduce. Please also list any relevant details for your test configuration

### Test Configuration

- Kubernetes version

## Checklist

- [ ] My changes follows the style guidelines of this project
- [ ] I have performed a self-review of my own changes
- [ ] I confirm that my change can be rendered via `helm template`
- [ ] I confirm that my change passes `helm lint`
- [ ] I confirm that `pre-commit run` was run and all checks passed
- [ ] I have updated the documentation accordingly
- [ ] I have updated the chart version in `Chart.yaml` file and this change follow [semantic versioning](https://semver.org/) as described in the `CONTRIBUTING.md`
