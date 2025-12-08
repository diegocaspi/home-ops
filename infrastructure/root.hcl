remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket                      = "home-ops-remote-state"
    key                         = "${path_relative_to_include()}/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    access_key                  = "${get_env("R2_ACCESS_KEY")}"
    secret_key                  = "${get_env("R2_ACCESS_SECRET")}"
    endpoints                   = { s3 = "https://${get_env("CLOUDFLARE_ACCOUNT_ID")}.r2.cloudflarestorage.com" }
  }
}

locals {
  module_name = basename(get_terragrunt_dir())
  # Convert module-name to MODULE_NAME format
  env_var_name = upper(replace(local.module_name, "-", "_"))
}

terraform {
  # Force OpenTofu/Terraform to keep trying to acquire a lock for
  # up to 20 minutes if someone else already has the lock
  extra_arguments "env_vars" {
    commands = [
      "init",
      "apply",
      "refresh",
      "import",
      "plan",
      "taint",
      "untaint"
    ]

    env_vars = {
      TF_VAR_proxmox_api_token = get_env("PROXMOX_${local.env_var_name}_API_TOKEN", "")
      TF_VAR_proxmox_ssh_user = get_env("PROXMOX_${local.env_var_name}_SSH_USER", "tofu")
    }
  }
}
