repo := module_directory() + "/.."

# Bootstrap the nova cluster with Flux Operator
bootstrap-nova:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ -z "${OCI_TOKEN:-}" ]]; then
      echo "OCI_TOKEN must be set in the environment." >&2
      exit 1
    fi

    if [[ -z "${ONEPASSWORD_TOKEN:-}" ]]; then
      echo "ONEPASSWORD_TOKEN must be set in the environment." >&2
      exit 1
    fi

    if command -v tofu >/dev/null 2>&1; then
      tf=tofu
    elif command -v terraform >/dev/null 2>&1; then
      tf=terraform
    else
      echo "Neither tofu nor terraform is available in PATH." >&2
      exit 1
    fi

    cd "{{ repo }}/terraform"
    export TF_VAR_oci_token="${OCI_TOKEN}"
    export TF_VAR_onepassword_token="${ONEPASSWORD_TOKEN}"
    export TF_VAR_cluster_name="nova"
    export TF_VAR_cluster_region="tpi"

    "$tf" init
    "$tf" apply
