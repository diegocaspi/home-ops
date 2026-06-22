# Home Ops

This context defines the language used to discuss the `home-ops` repository and the `nova` cluster it operates.

## Language

**home-ops**:
The operations repository that defines and operates the `nova` cluster.
_Avoid_: cluster, homelab

**nova**:
The homelab Kubernetes cluster operated by `home-ops`.
_Avoid_: repo, environment

**active cluster**:
The cluster currently operated by `home-ops`; today this is **nova** only.
_Avoid_: environment, target

**automation target**:
An auxiliary GitOps target used to run maintenance automation, not an operated homelab cluster.
_Avoid_: cluster, environment

**lifecycle maintenance flow**:
The automation flow that proposes dependency or image updates without being part of the active cluster runtime.
_Avoid_: deployment flow, cluster operations

**Flux D2 model**:
The Flux reference architecture pattern where Git-tracked desired state is packaged as signed OCI artifacts and reconciled by Flux.
_Avoid_: plain GitOps, Git sync

**monorepo D2 layout**:
A repository layout that adapts the **Flux D2 model** into one repository instead of separate fleet, infrastructure, and apps repositories.
_Avoid_: multi-repo D2, standard D2 layout

**fleet layer**:
The part of the **GitOps payload** that defines cluster entrypoints and tenant wiring.
_Avoid_: cluster config, bootstrap layer

**infrastructure layer**:
The part of the **GitOps payload** that defines platform services and cluster capabilities.
_Avoid_: system apps, add-ons

**apps layer**:
The part of the **GitOps payload** that defines user-facing or application workloads.
_Avoid_: workloads, app manifests

**production-style homelab**:
A homelab environment operated with production-style practices, without implying production availability guarantees.
_Avoid_: production cluster, toy homelab

**bootstrap**:
The one-time process that installs the minimum cluster components needed for GitOps reconciliation to take over.
_Avoid_: install, deploy

**GitOps payload**:
The desired cluster state published by the repository for Flux to reconcile.
_Avoid_: manifests, app bundle

**Gitless GitOps**:
A GitOps delivery model where desired state is tracked in Git but reconciled by the cluster from signed OCI artifacts instead of directly from Git.
_Avoid_: Git-free GitOps, direct Git sync

**tenant**:
A Flux-managed namespace and reconciliation boundary inside `nova`.
_Avoid_: team, customer

**infrastructure tenant**:
A tenant that reconciles platform capabilities required by the cluster or other workloads.
_Avoid_: system app, infra app

**apps tenant**:
A tenant that reconciles user-facing or application workloads.
_Avoid_: workload namespace, application folder

## Relationships

- **home-ops** operates **nova**.
- **nova** is the only **active cluster**.
- `update` is an **automation target**, not an **active cluster**.
- `update` supports the **lifecycle maintenance flow**.
- **home-ops** uses a **monorepo D2 layout** based on the **Flux D2 model**.
- A **monorepo D2 layout** contains the **fleet layer**, **infrastructure layer**, and **apps layer** in one repository.
- The **GitOps payload** contains the **fleet layer**, **infrastructure layer**, and **apps layer** as one signed artifact.
- **Gitless GitOps** describes how **nova** receives the **GitOps payload**.
- **bootstrap** enables **nova** to reconcile the **GitOps payload**.
- A **tenant** is either an **infrastructure tenant** or an **apps tenant**.
- An **infrastructure tenant** provides platform capabilities used by **apps tenants**.

## Example Dialogue

> **Dev:** "When rebuilding **nova**, do we apply every manifest manually?"
> **Domain expert:** "No. We run **bootstrap** so Flux can reconcile the **GitOps payload** through the defined **tenants**."

## Flagged Ambiguities

- "production ready" is not used as a documentation claim; use **production-style homelab** when describing the operating model.
