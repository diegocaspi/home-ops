# Operations

This document describes how to change `home-ops` safely without re-learning the architecture each time.

## Tooling

Use `mise install` as the default setup path. The repository toolchain is declared in `.mise.toml`.

Use `just --list` to inspect available recipes. The most important recipes are the Talos generation/apply/kubeconfig recipes and `terraform bootstrap-nova`.

## Validation Standard

Every workflow that changes cluster state should end with a local validation step and, when the change reaches `nova`, a live verification step.

Kubernetes and Flux manifest changes should run `hack/validate.sh -d kubernetes`. Talos changes should regenerate configs with `just talos gen` and then review the generated output intentionally. Terraform changes should be formatted and planned when kubeconfig and credentials are available.

Live verification is separate from local validation. Local validation catches rendering and schema issues. Live verification confirms that Flux, CRDs, credentials, runtime substitutions, and controllers accepted the change in `nova`.

## Changing Infrastructure

Infrastructure components live under `kubernetes/infrastructure/`. Components are split into `controllers/` and `configs/` where that distinction matters: controllers install or manage platform services, while configs apply custom resources or runtime configuration after controllers exist.

When adding or changing an infrastructure component, update the component path first, then update tenant wiring only if a new tenant or reconciliation input is required. The infrastructure ResourceSet is `kubernetes/tenants/infrastructure.yaml`.

The expected path after merge is that GitHub Actions publishes a new signed artifact, Flux notices the artifact revision, and the relevant infrastructure tenant Kustomizations reconcile from the new path.

## Changing Apps

Application workloads live under `kubernetes/apps/`. App tenant wiring lives in `kubernetes/tenants/apps.yaml`.

Use the apps layer for user-facing workloads. If an app needs cluster-wide resources, treat those as platform-owned infrastructure and place them in the infrastructure layer instead of giving the app tenant broader responsibility by default.

## Lifecycle Maintenance

The lifecycle maintenance flow proposes updates without being part of the active `nova` runtime.

`kubernetes/clusters/update/` defines the automation target. `.github/workflows/e2e-update.yaml` creates a temporary Kubernetes environment, bootstraps Flux for update automation, reconciles update policies from `kubernetes/update-policies/`, and lets Flux image automation push changes to `chore/image-updates`.

`.github/workflows/image-updates.yaml` opens a pull request from that branch. After the PR is reviewed and merged, the normal artifact publishing workflow produces the artifact that `nova` can reconcile.

## Changing This Repo

Keep changes focused. Run the validation that matches the changed layer. After merge, GitHub Actions is responsible for publishing and signing the GitOps payload. Flux is responsible for reconciling the new artifact on `nova`.

Detailed agent and contribution guidance belongs in `AGENTS.md`.
