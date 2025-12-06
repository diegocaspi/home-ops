variable "proxmox_api_token" {
  description = "The Proxmox API token for authentication."
  type        = string
}

variable "proxmox_ssh_user" {
  description = "The SSH user for connecting to Proxmox."
  type        = string
  default     = "tofu"
}
