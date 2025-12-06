provider "proxmox" {
  # private tailscale endpoint
  endpoint  = "https://hypnos.zorilla-snares.ts.net:8006/"
  api_token = var.proxmox_api_token

  ssh {
    agent = true
    username = var.proxmox_ssh_user
  }
}
