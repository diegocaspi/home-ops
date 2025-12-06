## Configure SSH Access to Proxmox VE

To configure SSH access to your Proxmox VE server, follow these steps:
1. First of all, install `sudo` on your Proxmox VE server if it is not already installed:
   ```bash
   apt install sudo
   ```
2. Next, create a new user (preferred to be `tofu`):
   ```bash
    adduser tofu
    ```
3. Add the new user to the `sudo` group to grant administrative privileges by editing the sudoers file:
   ```bash
   visudo -f /etc/sudoers.d/tofu
   ```
   And add the following line:
   ```bash
   tofu ALL=(root) NOPASSWD: /sbin/pvesm
   tofu ALL=(root) NOPASSWD: /sbin/qm
   tofu ALL=(root) NOPASSWD: /usr/bin/tee /var/lib/vz/*
   ```
   If you're using a different datastore for snippets, not the default local, you should add the datastore's mount point to the sudoers file as well, for example:
   ```bash
   tofu ALL=(root) NOPASSWD: /usr/bin/tee /mnt/pve/cephfs/*
   ```
   You can find the mount point of the datastore by running `pvesh get /storage/<name>` on the Proxmox node.

4. Now, set up SSH key-based authentication for the new user. On your local machine, generate an SSH key pair if you don't already have one, then copy the public key to the `tofu` user's `~/.ssh/authorized_keys` file on the Proxmox server
