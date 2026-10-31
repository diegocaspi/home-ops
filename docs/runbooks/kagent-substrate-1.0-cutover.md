# Kagent 1.0 + Agent Substrate 1.0 cutover on nova

Applies to the `kagent` and `ate-system` tenants. Nothing from the 0.10.x /
0.0.9 installation is preserved: chat history, subscriptions, and all sandbox
snapshots are dropped. 1.0 has no in-place upgrade path (new CRD group
`api.kagent.dev/v1alpha3`, new Postgres baseline, replaced Agent model), so
this is a drop-and-reinstall per
[kagent docs](https://kagent.dev/docs/kagent/1.x/operations/upgrade-from-0x/).

Versions (lockstep, per kagent rc1): kagent `1.0.0-rc1`, Agent Substrate
`1.0.0-rc1`. Never bump substrate independently of kagent.

## 1. Kubernetes 1.37 first

kagent 1.x / substrate 1.0 need `PodCertificateRequest` and
`ClusterTrustBundle` (GA at `certificates.k8s.io/v1` in 1.37). The cluster runs
1.36.3 today and serves neither, so:

1. `talos/talconfig.yaml` → Talos v1.14.4 / kubernetes v1.37.1 (done in this
   change), plus the tuppr CRs in `kubernetes/tenants/system-upgrade/configs/`.
2. `just talos gen && just talos apply`, then let tuppr walk the cluster
   through Talos 1.14 and Kubernetes 1.37.
3. Verify before proceeding:

   ```bash
   KUBECONFIG=talos/clusterconfig/kubeconfig kubectl api-resources --api-group=certificates.k8s.io
   ```
   `podcertificaterequests` and `clustertrustbundles` must be listed.

   One prerequisite for later: 1Password items `kagent-postgres` and
   `substrate-postgres` (fields `username`, `password`) in the Homelab vault —
   they back the managed role passwords and the per-tenant `uri` secrets.

## 2. Drop the old installation

```bash
flux -n kagent delete helmrelease kagent kagent-crds
flux -n ate-system delete helmrelease substrate substrate-crds
kubectl delete ns kagent ate-system
```

The valkey snapshot store is gone in 1.0 (replaced by Postgres + RustFS), so
its StatefulSet, patches and runbook retire with it.

## 3. Flux installs the new stack

Push the new manifests; the tenants ResourceSet recreates the namespaces (the
`kagent` namespace now carries `ate.dev/api-access: "true"`, required to reach
the Substrate API), one shared CloudNativePG cluster (`shared-postgres` in
`cnpg-system`, hosting separate `kagent` and `substrate` databases via
declarative `Database` CRs), and the substrate + kagent HelmReleases at
1.0.0-rc1.

Both tenant manifests depend on the cnpg-system `configs` Kustomization
(shared Cluster + `Database` CRs ready), so HelmReleases only reconcile once
Postgres is up. The `kagent-postgres-app` / `substrate-postgres-app` Secrets
are ExternalSecrets: each templates the `uri` key
(`postgresql://<user>:<pw>@shared-postgres-rw.cnpg-system.svc:5432/<db>`)
from the 1Password items above, keeping the chart `secretKeyRef` values
pointing at per-tenant names.
RustFS (default enabled) stores snapshots in its 1Gi PVC on longhorn.

## 4. One-time identity bootstrap

Substrate needs signing-key pools (actor JWT, actor CA, egress MITM, pod
identity, service DNS, Postgres CA) that no chart creates — only
`kagent install` generates them, and Flux cannot adopt the pre-seeded release
any other way. Run the installer once, exactly matching the Flux values, then
let Flux take over the resulting releases (helm-controller sees an unmanaged
release and upgrades/adopts it).

```bash
export OPENAI_API_KEY=$(op item get kagent --fields API_KEY --reveal --account yours) # zen key
cat > /tmp/kagent-config.yaml <<EOF
install:
  kagent:
    valuesFiles: [/tmp/kagent-values.yaml]
  substrate:
    valuesFiles: [/tmp/substrate-values.yaml]
EOF
```

`/tmp/kagent-values.yaml` — identical to `spec.values` of the kagent
HelmRelease; `/tmp/substrate-values.yaml` — identical to the substrate
HelmRelease values. Then:

```bash
kagent --config /tmp/kagent-config.yaml install --namespace kagent \
  --skip-database-setup
```

Wait for completion, then verify Flux adoption:

```bash
flux -n ate-system reconcile helmrelease substrate --with-source
flux -n kagent reconcile helmrelease kagent --with-source
```

## 5. Verify

```bash
KUBECONFIG=talos/clusterconfig/kubeconfig kubectl get pods -n ate-system,kagent
KUBECONFIG=talos/clusterconfig/kubeconfig kubectl get workerpools -n kagent   # kagent-default ready
kagent agent list
kagent agent session create --agent <name>   # reply proves the whole path
```

Check `https://kagent.dcaspi.dev` via the HTTPRoute.

## Notes and known gaps

- `vectorEnabled` stays false: the CNPG 17 image has no pgvector, so 1.0
  long-term memory is off. Enable later only by switching to a pgvector image
  and rerunning migrations.
- The hermes Telegram bot (extraObject `AgentHarness hermes-shell`) is deleted:
  `AgentHarness` has no 1.0 equivalent. Recreate it as a Harness + AgentTemplate
  + Agent pair if still wanted.
- Renovate pins `1.0.0-rc1` manually; keep the pre-releases out of the stable
  tag flow until 1.0.0 GA, then align kagent-crds, kagent, substrate, substrate
crds and the worker image in one change and follow the release notes.
