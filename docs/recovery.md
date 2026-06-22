# Recovery

Recovery starts by identifying the failed layer. Avoid destructive actions until the failing boundary is clear.

## Failure Boundaries

Talos owns machine configuration and Kubernetes API availability.

Cilium owns pod networking. If Cilium is unhealthy, many higher-level symptoms can be misleading.

Flux Operator owns Flux lifecycle and the `FluxInstance`.

Flux source and kustomize controllers own artifact fetch, signature verification, and manifest reconciliation.

External Secrets owns synchronization from 1Password into Kubernetes Secrets.

Tenants own their namespace-scoped reconciliation from the signed artifact.

## Non-Destructive Checks

Prefer read-only checks first. Confirm that the Kubernetes API is reachable, nodes are ready, Cilium is running, Flux Operator is ready, the root `OCIRepository` can fetch and verify the artifact, and the root and tenant Kustomizations report ready.

For secret failures, confirm `ghcr-auth` exists where Flux needs artifact access, `onepassword-connect-token` exists in `external-secrets`, `ClusterSecretStore/onepassword` is ready, and the relevant `ExternalSecret` reports a successful sync.

For lifecycle maintenance failures, check the GitHub Actions run first. The update target is temporary and should be debugged from CI logs before assuming anything is wrong with `nova`.

## Safe Repair

Many bootstrap failures are safe to retry after fixing inputs. Missing local credentials, an incorrect kubeconfig, unreachable API server, or expired GHCR/1Password token should be corrected before rerunning bootstrap.

Manifest errors should be fixed in Git, validated locally, merged, and allowed to flow through the signed artifact pipeline.

If Flux is running but blocked on artifact verification, inspect the workflow, artifact tag, signature identity, and runtime substitution values before changing cluster resources.

## Destructive Escalation

Destructive actions include deleting namespaces, deleting Flux-managed resources by hand, wiping Talos nodes, replacing Longhorn storage, or rebuilding the cluster.

Use those only after confirming the failed layer and understanding the data loss or reconciliation impact. Do not delete Flux, tenant namespaces, Longhorn volumes, or Talos state as a generic troubleshooting step.

If a full rebuild is required, treat it as a Talos and bootstrap operation: restore or recreate the Kubernetes API first, then rerun bootstrap, then let Flux reconcile `nova` from the signed artifact.
