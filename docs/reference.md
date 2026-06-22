# Reference

This file records mutable operational facts. Each fact points to the source file that should be checked before updating the docs.

## Active Cluster

Active cluster: `nova`.

Source: `talos/talconfig.yaml`, `kubernetes/clusters/nova/`, `terraform/mod.just`.

Cluster endpoint: `https://192.168.2.144:6443`.

Source: `talos/talconfig.yaml`.

Kubeconfig expected by Terraform providers: `~/.kube/clusters/nova.yaml`.

Source: `terraform/providers.tf`.

## Versions

Talos: `v1.13.4`.

Kubernetes: `v1.36.0`.

Source: `talos/talconfig.yaml`.

OpenTofu: `1.10.7`.

Source: `.mise.toml`.

## Nodes

`controlplane` is the control-plane node at `192.168.2.144`.

`workload` is the worker node at `192.168.2.19`.

Both nodes are `arm64`, use NVMe install disks, use the Turing RK1 Talos overlay, and enable Longhorn disk creation.

Source: `talos/talconfig.yaml`.

## Talos Extensions

The Talos node image includes `siderolabs/iscsi-tools`, `siderolabs/rockchip-rknn`, and `siderolabs/util-linux-tools`.

Source: `talos/talconfig.yaml`.

## GitOps Artifact

Artifact repository: `oci://ghcr.io/diegocaspi/home-ops`.

Active cluster path inside the artifact: `clusters/nova`.

Source: `kubernetes/clusters/nova/flux-system/flux-instance.yaml`.

The publishing workflow is `.github/workflows/push-artifact.yaml`.

## Important Resources

Flux instance: `FluxInstance/flux` in `flux-system`.

Root pull secret: `ghcr-auth`.

Runtime information: `flux-runtime-info`.

1Password secret store: `ClusterSecretStore/onepassword`.

Initial 1Password token secret: `onepassword-connect-token` in `external-secrets`.

Sources: `terraform/main.tf`, `kubernetes/clusters/nova/flux-system/flux-instance.yaml`, `kubernetes/infrastructure/external-secrets/configs/nova/cluster-secret-store.yaml`.

## Workflows

Artifact publishing: `.github/workflows/push-artifact.yaml`.

Lifecycle maintenance: `.github/workflows/e2e-update.yaml` and `.github/workflows/image-updates.yaml`.

Validation helper: `hack/validate.sh`.

Just recipes: `justfile`, `talos/mod.just`, and `terraform/mod.just`.
