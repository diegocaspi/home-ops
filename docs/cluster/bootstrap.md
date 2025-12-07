# Bootstrap the Cluster with Flux Operator & Helmfile

Once the `infrastructure` and `talos` layers have been properly configured, the next step involves bootstrapping the cluster to automatically reconcile the resources defined in the Git repository, following GitOps principles. This bootstrap process is carefully designed to ensure a seamless handoff from imperative installation to declarative GitOps management, with zero configuration drift.

## The Bootstrap Challenge

When setting up a GitOps-managed Kubernetes cluster, there's an inherent chicken-and-egg problem: how do you install Flux itself when Flux is responsible for managing the cluster's state? Moreover, certain critical components like the CNI (Container Network Interface) must be present before Flux can even function. The bootstrap process must install these foundational components in a way that allows Flux to take over their management without detecting any configuration differences that would trigger unnecessary reconciliation.

## Helmfile-Based Bootstrap

This repository uses [Helmfile](https://helmfile.readthedocs.io/) to perform the initial bootstrap. Helmfile provides a declarative way to deploy Helm charts, which makes it ideal for this one-time installation step. The bootstrap is orchestrated by `bootstrap/helmfile.yaml`, which installs four critical components in a specific order:

1. **Cilium** - The CNI provider that enables pod networking
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

## Special Handling: Cilium

Cilium requires slightly different treatment because it's the CNI - it must be fully operational before any other pods can network. Additionally, Cilium has custom resources (like `CiliumLoadBalancerIPPool`) that need to be applied after the Cilium operator is running but before Flux starts.

The helmfile installs Cilium directly from an OCI registry (`oci://ghcr.io/home-operations/charts-mirror/cilium`) and uses post-sync hooks to ensure proper sequencing:

1. First hook waits for Cilium CRDs to become available by polling for `ciliumloadbalancerippools.cilium.io`
2. Second hook applies the Cilium networking configuration from `kubernetes/apps/kube-system/cilium/app/networking.yaml`

## The Smooth Handoff

The carefully orchestrated bootstrap process results in a seamless transition to GitOps management:

1. **Helmfile runs** and installs all components with values sourced directly from the kubernetes layer
2. **Flux Instance is created** as the final bootstrap step, configured to sync from this Git repository
3. **Flux initializes** and reads the desired state from `kubernetes/flux/cluster`
4. **Flux evaluates** the cluster's current state against the Git repository
5. **No changes detected** - everything matches because bootstrap used the same configurations
6. **Flux takes over** ongoing management without disruption

From this point forward, any changes to component configurations are made by updating the HelmRelease manifests in the `kubernetes/apps/` directory, committing to Git, and allowing Flux to reconcile. The bootstrap process doesn't need to run again unless the cluster is being rebuilt from scratch.

## Running the Bootstrap

The bootstrap is executed via the devenv script:

```bash
boot
```

This script internally runs:

```bash
helmfile -f bootstrap/helmfile.yaml sync
```

The sync operation will:
- Install or upgrade each release in dependency order
- Execute post-sync hooks for Cilium
- Wait for Flux Instance to become ready
- Leave you with a fully GitOps-managed cluster

After bootstrap completes, you can verify Flux is operating correctly:

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

If you ever need to re-bootstrap the cluster, Helmfile will automatically pick up those changes because it reads from the same HelmRelease files. The single source of truth remains the kubernetes layer, whether you're bootstrapping or letting Flux manage ongoing operations.

This design philosophy - using the GitOps manifests as the source of truth even during bootstrap - is what enables truly declarative cluster management from day one.
