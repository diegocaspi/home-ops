# Bootstrap

Bootstrap is the one-time handoff from a provisioned Kubernetes API to Flux-managed cluster reconciliation.

For `nova`, bootstrap is handled by the Terraform/OpenTofu module in `terraform/`. It installs the minimum components required for Flux to reconcile the signed GitOps payload from GHCR.

## Preconditions

Talos must already provide a reachable Kubernetes API for `nova`. The kubeconfig expected by the Terraform providers is `~/.kube/clusters/nova.yaml`.

Install the local toolchain with `mise install`. If not using mise, install the tools listed in `.mise.toml` manually.

The bootstrap command requires two local credentials. `OCI_TOKEN` is used to create the GHCR pull secret consumed by Flux. `ONEPASSWORD_TOKEN` is used to create the initial `onepassword-connect-token` secret required before External Secrets can reconcile steady-state secrets.

## Command

The canonical bootstrap entrypoint is:

`OCI_TOKEN=... ONEPASSWORD_TOKEN=... just terraform bootstrap-nova`

The recipe selects `tofu` when available and falls back to `terraform`. It sets the cluster variables for `nova`, initializes the module, and applies it from `terraform/`.

## What Bootstrap Creates

Bootstrap installs Cilium from the values in `kubernetes/infrastructure/kube-system/controllers/nova/cilium.values.yaml`.

It installs Flux Operator and creates the `FluxInstance` from `kubernetes/clusters/nova/flux-system/flux-instance.yaml`.

It creates the `ghcr-auth` secret so Flux can pull the private GHCR artifact, runtime information used by Flux substitutions, the `external-secrets` namespace, and the initial `onepassword-connect-token` secret.

After that point, Flux reconciles `clusters/nova` from `oci://ghcr.io/diegocaspi/home-ops`.

## Verification

Local validation checks whether the GitOps payload renders and validates before merge. Use `hack/validate.sh -d kubernetes` for Kubernetes changes.

Live verification checks that the cluster accepted the bootstrap and is reconciling. The expected signal is that Flux Operator, the Flux controllers, the root `OCIRepository`, and the root Kustomizations report ready, and tenant reconciliation begins from the signed artifact.

Bootstrap is intended to be rerunnable after fixing missing credentials, an unreachable API server, or a failed prerequisite. Destructive rebuild steps belong in `docs/recovery.md`, not in the normal bootstrap path.
