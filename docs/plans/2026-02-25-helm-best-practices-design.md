# Helm Best Practices Pipeline Design

**Date:** 2026-02-25

## Goal

Implement a comprehensive quality pipeline for the universal-chart Helm repo covering: PR quality gates, chart unit testing, automated docs generation, and security scanning.

## Current State

- Single `release.yaml` workflow: `helm lint --strict` + `helm template` smoke test + OCI push to GHCR
- No schema validation, no unit tests, no docs generation, no security scanning
- Mixed `.yml`/`.yaml` template file extensions (cosmetic, not functional)

## Design

### Workflow Structure

Replace `release.yaml` with two workflow files:

#### `ci.yaml` (push to main + all PRs)

```
jobs:
  lint:     helm lint --strict + helm template + kubeconform + helm-unittest
  security: trivy config over rendered manifests (informational on PR, blocks release on main push)
  release:  push-only, needs: [lint, security] — helm package + helm push OCI
```

#### `docs.yaml` (push to main only)

```
jobs:
  helm-docs: run helm-docs, git diff, commit README if changed
             (skips commit if github.actor == 'github-actions[bot]')
```

### Tools

| Tool | Version | Purpose |
|---|---|---|
| `kubeconform` | v0.6.x | Validate rendered YAML against k8s JSON schemas |
| `helm-unittest` | v0.4.x | Structured template unit tests |
| `helm-docs` | v1.x | Generate README from `# --` value annotations |
| `trivy config` | latest | Security misconfiguration scanning |

### kubeconform Configuration

Configured with two schema sources:
1. Default k8s schema (kubernetes-version 1.28)
2. datreeio CRD catalog for ESO, cert-manager, Istio, Gateway API types

Unknown schema types: `--ignore-missing-schemas` (graceful skip for unregistered CRDs)

### helm-unittest Test Suites

Location: `universal-chart/tests/`

Suites to create:
- `deployment_test.yaml` — kind, apiVersion, name, labels
- `service_test.yaml` — kind, apiVersion, name
- `externalsecret_test.yaml` — kind, apiVersion, namespace, spec passthrough
- `clusterissuer_test.yaml` — kind, no namespace field
- `httproute_test.yaml` — kind, apiVersion

### helm-docs

- Annotate `values.yaml` top-level keys with `# -- description` comments
- Output: `universal-chart/README.md`
- CI check: run helm-docs, fail PR if README would change
- On main push: run helm-docs, commit if changed (skip if bot actor)

### Security Scanning (Trivy)

```bash
helm template test universal-chart/ -f universal-chart/ci/test-values.yaml \
  | trivy config --exit-code 1 --severity HIGH,CRITICAL -
```

- On PRs: `--exit-code 0` (informational, never blocks)
- On main push (release job): `--exit-code 1` (blocks OCI push if HIGH/CRITICAL found)

## Trade-offs

- `kubeconform` will not validate CRD spec fields (only structural envelope) — acceptable since we use thin passthrough for CRDs anyway
- `helm-docs` auto-commit on main requires bot-actor guard to prevent CI loop
- Trivy may produce false positives on CI test values (e.g., `image: nginx` without pinned digest) — tune severity threshold if needed

## Success Criteria

- PRs blocked on lint failures, schema errors, unit test failures
- `helm-docs` README stays in sync with values.yaml
- Security issues surface in CI before OCI push
- All jobs pass on the current `ci/test-values.yaml`
