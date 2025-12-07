# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitOps-based home operations repository for managing a Kubernetes cluster running on Talos OS, with infrastructure provisioned on Proxmox VE using OpenTofu/Terragrunt. The cluster uses FluxCD for continuous deployment and follows GitOps principles.

## Architecture

### Three-Layer Infrastructure Stack

1. **Infrastructure Layer** (`infrastructure/`)
   - Uses OpenTofu + Terragrunt to provision Proxmox VMs
   - Terragrunt configuration in `infrastructure/root.hcl` defines remote state backend (Cloudflare R2)
   - Shared Proxmox module at `infrastructure/shared/proxmox/` defines VM resources
   - Per-host configurations in `infrastructure/hosts/` (e.g., `hypnos/`)
   - Each host's `terragrunt.hcl` includes the root config and specifies node configurations

2. **Talos Layer** (`talos/`)
   - Talos OS cluster configuration using `talhelper`
   - `talconfig.yaml` defines cluster nodes, versions, and configuration
   - Generated configs output to `talos/clusterconfig/`
   - Secrets encrypted with SOPS/age (`.sops.yaml` configuration)
   - Cluster named "nova" running Talos v1.11.5 with Kubernetes v1.34.0

3. **Kubernetes Layer** (`kubernetes/`)
   - GitOps-managed using FluxCD
   - Structure:
     - `kubernetes/flux/` - Flux cluster-level Kustomizations
     - `kubernetes/apps/` - Application deployments organized by namespace
     - `kubernetes/components/` - Reusable Kubernetes components
   - Core apps: Cilium (CNI), CoreDNS, Flux Operator/Instance
   - Flux Kustomization at `kubernetes/flux/cluster/ks.yaml` applies patches to set default behaviors for all child resources

### Bootstrap Process

The bootstrap process is split into two stages to properly support Gateway API in Cilium:

**Stage 1: CRD Installation** (`bootstrap/helmfile.crds.yaml`)
- Gateway API CRDs must be installed first to enable Cilium's Gateway API support
- Executed via `boot-crds` command

**Stage 2: Application Bootstrap** (`bootstrap/helmfile.apps.yaml`)
- Installs critical cluster components before Flux takes over:
  1. Cilium (CNI) - from OCI registry with networking config and Gateway API support
  2. CoreDNS - depends on Cilium
  3. Flux Operator - depends on Cilium
  4. Flux Instance - depends on Flux Operator
- Executed via `boot-apps` command

After bootstrap, Flux GitRepository monitors this repo and reconciles changes automatically.

## Development Environment

This repository uses `devenv` (Nix-based development environment):
- Configuration in `devenv.nix` and `devenv.yaml`
- Packages: git, yq, kubectl, helm, helmfile, holos, sops, age, talosctl, talhelper, terragrunt, opentofu
- Environment variables loaded from `.env` via `dotenv.enable = true`

Required environment variables (store in `.env`):
- `R2_ACCESS_KEY`, `R2_ACCESS_SECRET`, `CLOUDFLARE_ACCOUNT_ID` - for Terragrunt remote state
- `PROXMOX_<HOSTNAME>_API_TOKEN` - Proxmox API tokens per host (e.g., `PROXMOX_HYPNOS_API_TOKEN`)
- `PROXMOX_<HOSTNAME>_SSH_USER` - SSH user for Proxmox (defaults to "tofu")

## Common Commands

All commands below are defined as scripts in `devenv.nix` and available in the devenv shell:

### Infrastructure (OpenTofu + Terragrunt)
```bash
infra-plan   # Run terragrunt plan for all infrastructure modules
infra-apply  # Run terragrunt apply for all infrastructure modules
```

Direct terragrunt usage:
```bash
cd infrastructure/hosts/<hostname>
terragrunt plan
terragrunt apply
```

### Talos Cluster Management
```bash
talos-gen     # Generate Talos configs from talconfig.yaml using talhelper
talos-encrypt # Encrypt talos/talsecret.sops.yaml using SOPS
talos-apply   # Apply Talos configuration to cluster nodes (uses talos/apply.sh)
```

Manual Talos operations:
```bash
talosctl --nodes <ip> apply-config --file talos/clusterconfig/<cluster>-<hostname>.yaml
talosctl kubeconfig --nodes <ip>  # Get kubeconfig
```

### Kubernetes Bootstrap
```bash
boot-crds  # Install Gateway API CRDs (required first for Cilium Gateway API support)
boot-apps  # Bootstrap cluster with Cilium, CoreDNS, and Flux
```

Manual bootstrap:
```bash
# Step 1: Install CRDs first
helmfile -f bootstrap/helmfile.crds.yaml template -q | \
  yq 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -

# Step 2: Bootstrap applications (after CRDs are applied)
helmfile -f bootstrap/helmfile.apps.yaml sync
```

### Working with Secrets
```bash
# Edit encrypted Talos secrets
sops talos/talsecret.sops.yaml

# Encrypt a new file
sops -e -i <file>
```

SOPS configuration in `.sops.yaml` uses age encryption for files matching `talos/.+\.sops\.yaml`.

## Key File Locations

- `infrastructure/root.hcl` - Terragrunt root configuration (remote state, env vars)
- `infrastructure/shared/proxmox/main.tf` - Proxmox VM resource definitions
- `infrastructure/hosts/<hostname>/terragrunt.hcl` - Per-host VM specifications
- `talos/talconfig.yaml` - Talos cluster definition (nodes, IPs, versions)
- `talos/apply.sh` - Script to apply Talos configs to all nodes from talconfig.yaml
- `bootstrap/helmfile.crds.yaml` - CRD installation for bootstrap (Gateway API)
- `bootstrap/helmfile.apps.yaml` - Initial cluster bootstrap (pre-Flux)
- `kubernetes/flux/cluster/ks.yaml` - Main Flux Kustomization with patches for all apps
- `kubernetes/apps/<namespace>/<app>/` - Application manifests organized by namespace

## Proxmox Setup Requirements

For Terragrunt/OpenTofu to manage Proxmox VMs, the Proxmox host requires:
- A non-root user (recommended: `tofu`) with sudo privileges for specific commands
- SSH key-based authentication configured
- Sudoers configuration for `pvesm`, `qm`, and `tee` commands to specific paths

See `docs/infrastructure/proxmox.md` for detailed setup instructions.

## GitOps Workflow

1. Make changes to Kubernetes manifests in `kubernetes/apps/` or `kubernetes/flux/`
2. Commit and push to Git
3. Flux automatically detects changes and reconciles cluster state
4. For infrastructure changes:
   - Modify Terragrunt configs in `infrastructure/hosts/`
   - Run `infra-plan` then `infra-apply`
5. For Talos changes:
   - Edit `talos/talconfig.yaml`
   - Run `talos-gen`, `talos-encrypt` (if secrets changed), then `talos-apply`

## Cluster Information

- Cluster name: nova
- Control plane endpoint: https://192.168.2.58:6443
- Nodes defined in `talos/talconfig.yaml`:
  - controlplane: 192.168.2.58
  - workload: 192.168.2.202
- Scheduling allowed on control plane nodes
- All nodes use `/dev/sda` as install disk
