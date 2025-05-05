
# llm-d Helm Chart for OpenShift

See [charts/llm-d/README.md](charts/llm-d/README.md).

## Contributing

Before submitting a pull request, please ensure that you have following dependencies installed and set up:

- [Helm](https://helm.sh/)
- [Helm docs](https://github.com/norwoodj/helm-docs)
- [pre-commit](https://pre-commit.com/)

Then run:

```bash
pre-commit install
pre-commit run -a
```

Please address any linting issues that are flagged during validation. Once all linting problems have been resolved,
update the version number in the [`charts/llm-d/Chart.yaml`](charts/llm-d/Chart.yaml) file using
[semantic versioning](https://semver.org/). Follow the `X.Y.Z` format so the nature of the changes is reflected in the
chart.

- `X` (major) is incremented for breaking changes,
- `Y` (minor) is incremented when new features are added without breaking existing functionality,
- `Z` (patch) is incremented for bug fixes, minor improvements, or non-breaking changes.

## Deploying llm-d

See the [quickstart installer readme](quickstart/README.md) for instructions
