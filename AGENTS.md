# Repository Guidelines

## Project Structure & Module Organization

This repository manages the `nova` homelab cluster declaratively. `talos/` contains Talos cluster topology, generated cluster configs, and Talos operation recipes. `terraform/` contains the OpenTofu/Terraform bootstrap module that installs Flux Operator and prerequisite resources. `kubernetes/` is the GitOps payload published to GHCR and reconciled by Flux, with `kubernetes/clusters/nova/` as the cluster entrypoint, `kubernetes/infrastructure/` for platform components, and `kubernetes/tenants/` for tenant Flux resources. `docs/` holds operational notes, and `hack/validate.sh` is the local validation helper.

## Build, Test, and Development Commands

- `just --list`: show available repository recipes.
- `just talos gen`: generate Talos machine configs into `talos/clusterconfig/`.
- `just talos encrypt`: encrypt `talos/talsecret.sops.yaml` with SOPS.
- `just talos apply`: apply generated Talos configs to nodes from `talos/talconfig.yaml`.
- `just talos kubeconfig`: write kubeconfig to `talos/clusterconfig/kubeconfig`.
- `OCI_TOKEN=... ONEPASSWORD_TOKEN=... just terraform bootstrap-nova`: initialize and apply the bootstrap module from `terraform/`.
- `hack/validate.sh -d kubernetes`: validate YAML, Kubernetes manifests, and Kustomize overlays with `yq`, `kustomize`, `kubeconform`, and Flux schemas.

## Coding Style & Naming Conventions

Use two-space YAML indentation and keep Kubernetes manifests grouped by component under `controllers/` and `configs/`, with `base/` for shared resources and `nova/` for cluster-specific overlays. Prefer lowercase, hyphenated resource names such as `external-secrets` or `cluster-secret-store`. Keep Terraform files formatted with `tofu fmt` or `terraform fmt`. Shell scripts should use Bash with `set -euo pipefail` for operational recipes.

## Testing Guidelines

Run `hack/validate.sh` before changing Flux, Kustomize, or Kubernetes YAML. The script skips Secrets because SOPS metadata can fail schema validation, but it still validates ordinary YAML syntax and Kustomize render output. For Terraform changes, run `tofu fmt` and a targeted `tofu plan` from `terraform/` when credentials and kubeconfig are available.

## Commit & Pull Request Guidelines

Recent history uses Conventional Commit prefixes, especially `fix:`, `feat:`, and `chore:`. Keep messages imperative and scoped to the changed behavior, for example `fix: tenant name o11y` or `feat: external-dns unifi webhook`. Pull requests should describe the operational impact, list validation commands run, link related issues when present, and include screenshots only for UI-facing cluster services.

## Security & Configuration Tips

Do not commit plaintext secrets or local kubeconfigs. Keep `talos/talsecret.sops.yaml` encrypted, use `.env` only for local tokens, and pass bootstrap credentials through `OCI_TOKEN` and `ONEPASSWORD_TOKEN`. Avoid editing generated files in `talos/clusterconfig/` unless regenerating from source config.
