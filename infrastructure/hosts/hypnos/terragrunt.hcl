include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../shared/proxmox"
}

inputs = {
  host_name       = "hypnos"
  nodes           = [
    {
      name          = "k8s-controlplane-1"
      id            = 100
      order         = 1
      cpu_cores     = 2
      ram_dedicated = 4096
      disk_storage  = "vms1"
      disk_size_gb  = 48
    },
    {
      name          = "k8s-worker-1"
      id            = 101
      order         = 2
      cpu_cores     = 3
      ram_dedicated = 4096
      disk_storage  = "vms1"
      disk_size_gb  = 48
    },
  ]
}
