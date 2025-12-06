variable "host_name" {
  description = "The IP address or hostname of the Proxmox VE host."
  type        = string
}

variable "nodes" {
  description = "The list of Proxmox VE virtual machines to create."
  type = list(object({
    name          = string
    id            = number
    order         = number
    cpu_cores     = number
    ram_dedicated = number
    disk_storage  = string
    disk_size_gb  = number
  }))
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.host_name
  # talos 1.11.5 no cloud image, with qemu agent support
  url       = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.11.5/nocloud-amd64.iso"
  file_name = "talos-amd64.iso"
}

resource "proxmox_virtual_environment_vm" "talos_vm" {
  for_each = { for input in var.nodes : input.name => input }
  name        = each.key
  description = "Virtual machine running Talos OS"
  tags        = ["opentofu", "talos", "kubernetes"]

  node_name = each.key
  vm_id     = each.value.id

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
  }

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  startup {
    order      = "${each.value.order}"
    up_delay   = "30"
    down_delay = "30"
  }

  cpu {
    cores        = each.value.cpu_cores
    type         = "x86-64-v2-AES"  # recommended for modern CPUs
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  cdrom {
    enabled = true
    file_id = proxmox_virtual_environment_download_file.talos_iso.id
  }

  disk {
    datastore_id  = each.value.disk_storage
    interface     = "scsi0"
    size          = each.value.disk_size_gb
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }
}
