# Architecture

`home-ops` operates the `nova` Kubernetes cluster with Talos, Terraform/OpenTofu, Flux Operator, and signed OCI artifacts.

The cluster does not reconcile this Git repository directly. GitHub Actions packages the `kubernetes/` tree as an OCI artifact in GHCR, signs it with keyless cosign signing, and Flux reconciles paths from that artifact.

## Operating Model

Talos owns machine and Kubernetes control-plane configuration. The source topology is `talos/talconfig.yaml`; generated machine configs live under `talos/clusterconfig/`.

Terraform/OpenTofu performs bootstrap after the Kubernetes API exists. It installs the Flux Operator bootstrap module, Cilium prerequisites, the `FluxInstance`, runtime information, GHCR pull credentials, and the initial External Secrets token needed before steady-state reconciliation can take over.

Flux Operator manages Flux through `FluxInstance`. The active cluster entrypoint is `kubernetes/clusters/nova/`, and Flux reconciles it from the signed GHCR artifact.

ResourceSets define tenant reconciliation boundaries. Tenants receive runtime information and GHCR credentials copied from `flux-system`, then reconcile infrastructure or application paths from the same artifact.

## Flux D2 Mapping

This repository follows the Flux D2 delivery model but adapts the standard multi-repository layout into one repository.

| Flux D2 concept | Standard D2 layout | `home-ops` monorepo layout |
| --- | --- | --- |
| Fleet repository | `d2-fleet` | `kubernetes/clusters/` and `kubernetes/tenants/` |
| Infrastructure repository | `d2-infra` | `kubernetes/infrastructure/` |
| Apps repository | `d2-apps` | `kubernetes/apps/` |
| Fleet artifact | Separate OCI artifact | `ghcr.io/diegocaspi/home-ops` |
| Infrastructure artifact | Separate OCI artifact | Same artifact, different paths |
| Apps artifact | Separate OCI artifact | Same artifact, different paths |
| Update cluster | Temporary automation cluster | `kubernetes/clusters/update/` automation target |

The result is Gitless GitOps in the D2 sense: desired state is still tracked in Git, but the cluster reconciles signed OCI artifacts instead of pulling manifests directly from Git.

## Layers

The fleet layer is `kubernetes/clusters/nova/` plus `kubernetes/tenants/`. It defines the active cluster entrypoint and the ResourceSets that create tenant reconciliation.

The infrastructure layer is `kubernetes/infrastructure/`. It contains platform services such as Cilium, External Secrets, cert-manager, networking, storage, and observability.

The apps layer is `kubernetes/apps/`. It contains user-facing or application workloads.

The lifecycle maintenance flow is represented by `kubernetes/clusters/update/` and `kubernetes/update-policies/`. It exists to propose updates and is not part of the active `nova` runtime.

## External References

The closest upstream reference is the Flux D2 Reference Architecture from ControlPlane. This repo intentionally keeps the D2 reconciliation pattern while simplifying repository and artifact boundaries for a homelab operator.

- [Flux D2 Reference Architecture](https://github.com/controlplaneio-fluxcd/distribution/tree/main/docs)
- [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)
- [ResourceSet API](https://github.com/controlplaneio-fluxcd/flux-operator/blob/main/docs/resourcesets.md)
