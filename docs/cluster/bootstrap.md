# Bootstrap the Cluster with Flux Operator & Helmfile

Once the `infrastructure` and `talos` layers have been properly configured, the next step involves bootstrapping the cluster to automatically reconcile the resources defined in the Git repository, following GitOps principles. This bootstrap process is carefully designed to ensure a seamless handoff from imperative installation to declarative GitOps management, with zero configuration drift.

## The Bootstrap Challenge

When setting up a GitOps-managed Kubernetes cluster, there's an inherent chicken-and-egg problem: how do you install Flux itself when Flux is responsible for managing the cluster's state? Moreover, certain critical components like the CNI (Container Network Interface) must be present before Flux can even function. The bootstrap process must install these foundational components in a way that allows Flux to take over their management without detecting any configuration differences that would trigger unnecessary reconciliation.

## Helmfile-Based Bootstrap

This repository uses [Helmfile](https://helmfile.readthedocs.io/) to perform the initial bootstrap. Helmfile provides a declarative way to deploy Helm charts, which makes it ideal for this one-time installation step. The bootstrap process is split into two stages:

### Stage 1: CRD Installation (`bootstrap/helmfile.crds.yaml`)

Before installing any applications, Gateway API CRDs must be installed first. This is required because Cilium uses Gateway API for advanced networking features. The CRDs are installed using server-side apply to ensure proper ownership and conflict resolution:

```bash
boot-crds
```

This command templates the helmfile, filters for CustomResourceDefinition resources, and applies them with the `bootstrap` field manager.

### Stage 2: Application Bootstrap (`bootstrap/helmfile.apps.yaml`)

Once the CRDs are in place, the actual applications can be installed. This helmfile orchestrates the installation of four critical components in a specific order:

1. **Cilium** - The CNI provider that enables pod networking with Gateway API support
2. **CoreDNS** - Cluster DNS resolution
3. **Flux Operator** - Manages Flux component lifecycle
4. **Flux Instance** - The actual Flux deployment that syncs from Git

Each component has carefully defined dependencies (`needs` directives) to ensure they're installed in the correct sequence. For instance, CoreDNS and Flux Operator both depend on Cilium being fully operational, while Flux Instance requires Flux Operator to be ready first.

## The Values Injection Pattern

The most elegant aspect of this bootstrap design is how it eliminates configuration drift between the bootstrap installation and ongoing Flux management. The challenge is straightforward: if Helmfile installs components with different values than what Flux expects, Flux will immediately attempt to "correct" the configuration when it starts, causing unnecessary reconciliation and potential disruption.

The solution is implemented through a clever Go template at `bootstrap/templates/values.yaml.gotmpl`:

```go
{{ (fromYaml (readFile (printf "../../../kubernetes/apps/%s/%s/app/helmrelease.yaml" .Release.Namespace .Release.Name))).spec.values | toYaml }}
```

This single line of templating performs a powerful operation: it dynamically reads the corresponding `HelmRelease` manifest from the `kubernetes/` layer and extracts the `.spec.values` section. By referencing the release's namespace and name, the template automatically locates the correct HelmRelease file in the GitOps repository structure.

### How It Works

When Helmfile processes a release like `coredns`, it:

1. Looks up the release namespace (`kube-system`) and name (`coredns`)
2. Constructs the path: `kubernetes/apps/kube-system/coredns/app/helmrelease.yaml`
3. Reads and parses the YAML file
4. Extracts the `.spec.values` object
5. Injects those exact values into the Helm installation

This means the values used during bootstrap are **identical** to the values Flux will use when it takes over management. There's no duplication, no manual synchronization required, and no possibility of drift - the bootstrap process literally uses the Flux configuration as its source of truth.

For example, when CoreDNS is installed during bootstrap, it receives the exact same configuration (replica count, image repository, server plugins, affinity rules, etc.) that's defined in `kubernetes/apps/kube-system/coredns/app/helmrelease.yaml`. When Flux starts and encounters the already-deployed CoreDNS installation, it sees that the current state matches the desired state and leaves it untouched.

## Special Handling: Cilium and Gateway API

Cilium requires special treatment for two reasons:

1. **It's the CNI** - it must be fully operational before any other pods can network
2. **Gateway API Support** - Cilium's Gateway API features require Gateway API CRDs to be present before installation

This is why the bootstrap is split into two stages. The Gateway API CRDs must be installed in Stage 1 before Cilium can be deployed with Gateway API support enabled.

Additionally, Cilium has custom resources (like `CiliumLoadBalancerIPPool`) that need to be applied after the Cilium operator is running but before Flux starts. The helmfile installs Cilium directly from an OCI registry (`oci://ghcr.io/home-operations/charts-mirror/cilium`) and uses post-sync hooks to ensure proper sequencing:

1. First hook waits for Cilium CRDs to become available by polling for `ciliumloadbalancerippools.cilium.io`
2. Second hook applies the Cilium networking configuration from `kubernetes/apps/kube-system/cilium/app/networking.yaml`

## The Smooth Handoff

The carefully orchestrated two-stage bootstrap process results in a seamless transition to GitOps management:

1. **Stage 1: CRDs are installed** via `boot-crds`, providing the API foundations (Gateway API)
2. **Stage 2: Helmfile runs** and installs all components with values sourced directly from the kubernetes layer
3. **Flux Instance is created** as the final bootstrap step, configured to sync from this Git repository
4. **Flux initializes** and reads the desired state from `kubernetes/flux/cluster`
5. **Flux evaluates** the cluster's current state against the Git repository
6. **No changes detected** - everything matches because bootstrap used the same configurations
7. **Flux takes over** ongoing management without disruption

From this point forward, any changes to component configurations are made by updating the HelmRelease manifests in the `kubernetes/apps/` directory, committing to Git, and allowing Flux to reconcile. The bootstrap process doesn't need to run again unless the cluster is being rebuilt from scratch.

## Running the Bootstrap

The bootstrap is executed in two stages via devenv scripts:

### Stage 1: Install CRDs

```bash
boot-crds
```

This command installs the Gateway API CRDs required for Cilium's Gateway API support. It internally runs:

```bash
helmfile -f bootstrap/helmfile.crds.yaml template -q | \
  yq 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -
```

This templates the helmfile, extracts only the CustomResourceDefinition resources, and applies them using server-side apply with the `bootstrap` field manager.

### Stage 2: Bootstrap Applications

Once the CRDs are successfully applied, proceed with the application bootstrap:

```bash
boot-apps
```

This script internally runs:

```bash
helmfile -f bootstrap/helmfile.apps.yaml sync --hide-notes --kube-context nova
```

The sync operation will:
- Install or upgrade each release in dependency order
- Execute post-sync hooks for Cilium
- Wait for Flux Instance to become ready
- Leave you with a fully GitOps-managed cluster

### Verification

After both stages complete, you can verify Flux is operating correctly:

```bash
kubectl get gitrepository -n flux-system
kubectl get kustomization -n flux-system
```

You should see the `flux-system` GitRepository pointing to this repository and Kustomizations being reconciled according to the configurations in `kubernetes/flux/cluster`.

## Configuration Drift Prevention

This architecture ensures configuration drift cannot occur during the critical bootstrap-to-GitOps transition. If you need to modify how a component like CoreDNS or Flux is configured:

1. Edit the HelmRelease in `kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml`
2. Commit the change to Git
3. Flux automatically detects and applies the change

If you ever need to re-bootstrap the cluster, remember to run both stages in order:
1. First `boot-crds` to install/update CRDs
2. Then `boot-apps` to bootstrap applications

Helmfile will automatically pick up any configuration changes because it reads from the same HelmRelease files. The single source of truth remains the kubernetes layer, whether you're bootstrapping or letting Flux manage ongoing operations.

This design philosophy - using the GitOps manifests as the source of truth even during bootstrap, combined with proper CRD pre-installation for advanced features - is what enables truly declarative cluster management from day one.
