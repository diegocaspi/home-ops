# Secrets

Secrets in `home-ops` are split between encrypted source files, local-only operator credentials, bootstrap-created Kubernetes secrets, and External Secrets-managed runtime secrets.

Do not commit plaintext secrets, kubeconfigs, or local tokens.

## Repository Secrets

`talos/talsecret.sops.yaml` is encrypted with SOPS. The encryption rule is `.sops.yaml`.

Generated Talos configs and local kubeconfig output live under `talos/clusterconfig/`. Treat them as local operational artifacts, not documentation sources.

## Local Credentials

Bootstrap expects `OCI_TOKEN` and `ONEPASSWORD_TOKEN` in the local environment. A local `.env` file can be used by the operator but must remain uncommitted.

`OCI_TOKEN` gives Flux access to pull the GHCR artifact. GHCR does not support cluster-side workload identity for this use case, so a token-backed pull secret is required.

`ONEPASSWORD_TOKEN` is used only to seed the initial Kubernetes secret that lets External Secrets reach 1Password.

## Kubernetes Secret Contract

Terraform bootstrap creates `ghcr-auth` for GHCR artifact pulls and `onepassword-connect-token` in the `external-secrets` namespace.

External Secrets uses `ClusterSecretStore/onepassword` as the Kubernetes-side integration point. `ExternalSecret` resources pull secret material into Kubernetes Secrets. `PushSecret` resources can write generated material back to 1Password where configured.

Flux Operator copies selected non-runtime objects, such as `ghcr-auth`, into tenant namespaces with the `fluxcd.controlplane.io/copyFrom` annotation. It also copies `flux-runtime-info`, which is not a secret and must not contain confidential values.

This document intentionally does not list private 1Password item names. If a specific external key matters, use the manifest path as the source of truth.

## Rotation

Rotate local and external credentials at their source first. Then update the bootstrap input or External Secrets source as appropriate and verify the Kubernetes Secret consumers become ready again.

Use `docs/recovery.md` when Flux cannot pull artifacts, External Secrets cannot read 1Password, or generated secrets are missing.
