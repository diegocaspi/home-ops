# GitOps

`home-ops` uses Gitless GitOps in the Flux D2 sense: Git remains the source for review and history, but `nova` reconciles signed OCI artifacts from GHCR.

## Artifact Publishing

`.github/workflows/push-artifact.yaml` packages the `kubernetes/` tree and publishes it to `ghcr.io/diegocaspi/home-ops`.

The workflow uses GitHub Actions identity for keyless cosign signing. Flux verifies the artifact signature before reconciliation. The expected identity is constrained in the `FluxInstance` and tenant `OCIRepository` definitions so artifacts must come from the approved workflow and Git ref.

The repository currently publishes one signed artifact that contains the fleet layer, infrastructure layer, and apps layer.

## Cluster Sync

`kubernetes/clusters/nova/flux-system/flux-instance.yaml` defines the active cluster sync. It points Flux at `oci://ghcr.io/diegocaspi/home-ops`, ref `latest`, path `clusters/nova`, and pull secret `ghcr-auth`.

The root cluster path applies Flux system resources and `kubernetes/clusters/nova/tenants.yaml`. The tenants Kustomization reconciles `./tenants` from the same artifact.

## Tenants

Tenants are Flux-managed namespaces and reconciliation boundaries.

`kubernetes/tenants/infrastructure.yaml` defines platform tenants such as `kube-system`, `external-secrets`, `cert-manager`, `networking`, `longhorn-system`, and `o11y`.

`kubernetes/tenants/apps.yaml` defines application tenant wiring.

ResourceSets create namespaces, copy runtime information and GHCR credentials, create Flux service accounts, and create tenant-scoped `OCIRepository` and `Kustomization` resources. Tenants reconcile paths from the same signed artifact using runtime substitutions such as artifact tag, cluster name, workflow name, and Git ref.

## Runtime Information

`flux-runtime-info` carries non-secret values used by Flux substitutions. It must not contain confidential data because it is copied into tenant namespaces.

Runtime values are part of the guardrail model. They help tenant `OCIRepository` resources verify that the artifact was signed by the expected GitHub Actions workflow and ref.

## Lifecycle Maintenance

The lifecycle maintenance flow follows the Flux D2 update automation pattern.

`kubernetes/clusters/update/` is an automation target. It enables Flux image reflector and image automation controllers in a temporary environment, reconciles update policies from `kubernetes/update-policies/`, and pushes proposed changes to `chore/image-updates`.

That target is not an active homelab cluster. It exists to create reviewable update pull requests; it is not part of serving workloads on `nova`.
