## Configure SSH Access to Proxmox VE

### Why SSH Access is Required

The [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) OpenTofu/Terraform provider requires SSH access to the Proxmox VE host to perform certain operations that are not available through the Proxmox API alone.

The provider uses both the Proxmox API (for VM lifecycle management) and SSH (for file operations and privileged commands).

### Dynamic Variable Injection

The repository uses a dynamic configuration pattern in `infrastructure/root.hcl` that automatically injects the correct credentials based on the Proxmox host being managed. This eliminates hardcoding and allows managing multiple Proxmox hosts with different credentials.

**How it works:**

1. Each Proxmox host has a dedicated folder under `infrastructure/hosts/<hostname>/` (e.g., `hypnos`)
2. The `root.hcl` extracts the folder name and converts it to uppercase with underscores:
   ```hcl
   locals {
     module_name = basename(get_terragrunt_dir())  # e.g., "hypnos"
     env_var_name = upper(replace(local.module_name, "-", "_"))  # e.g., "HYPNOS"
   }
   ```
3. Terragrunt automatically injects environment variables as OpenTofu variables:
   ```hcl
   env_vars = {
     TF_VAR_proxmox_api_token = get_env("PROXMOX_${local.env_var_name}_API_TOKEN", "")
     TF_VAR_proxmox_ssh_user = get_env("PROXMOX_${local.env_var_name}_SSH_USER", "tofu")
   }
   ```
4. Each host's `provider.tf` uses these variables to configure the provider:
   ```hcl
   provider "proxmox" {
     endpoint  = "https://hypnos.example.com:8006/"
     api_token = var.proxmox_api_token
     ssh {
       agent = true
       username = var.proxmox_ssh_user
     }
   }
   ```

**Example:** For a Proxmox host named `hypnos`, you would set:
- `PROXMOX_HYPNOS_API_TOKEN` - The API token for authentication
- `PROXMOX_HYPNOS_SSH_USER` - The SSH user (defaults to "tofu" if not set)

This pattern allows you to manage multiple Proxmox hosts (e.g., `hypnos`, `morpheus`, `nyx`) each with their own credentials, simply by following the naming convention.

### SSH User Configuration Steps

Follow these steps on each Proxmox VE host:

#### 1. Install sudo

First, install `sudo` if it's not already available:
```bash
apt install sudo
```

#### 2. Create a Dedicated User

Create a non-root user for OpenTofu operations (recommended name: `tofu`):
```bash
adduser tofu
```

**Note:** Using a dedicated user instead of root follows security best practices and allows for better audit logging.

#### 3. Configure Sudoers for Required Commands

The bpg/proxmox provider needs sudo access to specific Proxmox commands. Create a sudoers file:
```bash
visudo -f /etc/sudoers.d/tofu
```

Add the following rules to grant passwordless sudo access to required commands:
```bash
tofu ALL=(root) NOPASSWD: /sbin/pvesm
tofu ALL=(root) NOPASSWD: /sbin/qm
tofu ALL=(root) NOPASSWD: /usr/bin/tee /var/lib/vz/*
```

**Custom datastore configuration:**
If you're using a non-default datastore for snippets (not `local`), add its mount point. For example, for a CephFS datastore:
```bash
tofu ALL=(root) NOPASSWD: /usr/bin/tee /mnt/pve/cephfs/*
```

To find your datastore's mount point:
```bash
pvesh get /storage/<datastore-name>
```

#### 4. Set Up SSH Key-Based Authentication

The provider uses SSH agent authentication (`agent = true` in the provider configuration).

1. Generate an SSH key pair on your local machine if you don't already have one
2. Copy your public key and add it manually via the Proxmox console to the `tofu` user's `~/.ssh/authorized_keys` file
3. Verify SSH access works: `ssh tofu@<proxmox-host>`

### Environment Variable Setup

After configuring SSH on your Proxmox host, set the required environment variables in your `.env` file:

```bash
# For a Proxmox host named "hypnos"
PROXMOX_HYPNOS_API_TOKEN="user@pam!token-id=your-token-secret"
PROXMOX_HYPNOS_SSH_USER="tofu"

# For additional Proxmox hosts, follow the same pattern
# PROXMOX_<UPPERCASE_HOSTNAME>_API_TOKEN="..."
# PROXMOX_<UPPERCASE_HOSTNAME>_SSH_USER="..."
```

**Note:** The SSH user defaults to "tofu" if not specified, so you only need to set `PROXMOX_<HOST>_SSH_USER` if using a different username.

### Creating a Proxmox API Token

To generate the API token referenced in the environment variables:

1. Log into the Proxmox web interface
2. Navigate to **Datacenter → Permissions → API Tokens**
3. Click **Add** and configure:
   - **User:** Select or create a user (e.g., `terraform@pam`)
   - **Token ID:** A descriptive name (e.g., `opentofu`)
   - **Privilege Separation:** Unchecked (token inherits user permissions)
4. Click **Add** and copy the displayed token immediately (it won't be shown again)
5. Ensure the user has appropriate permissions (typically `PVEVMAdmin` role on `/`)

The token format will be: `user@pam!token-id=secret-value`

### Verification

After completing the configuration, verify everything works:

1. Ensure environment variables are loaded:
   ```bash
   echo $PROXMOX_HYPNOS_API_TOKEN
   echo $PROXMOX_HYPNOS_SSH_USER
   ```

2. Test Terragrunt can connect using the devenv script:
   ```bash
   infra-plan
   ```

If the plan succeeds without authentication errors, your SSH and API configuration is correct
