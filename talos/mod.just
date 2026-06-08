repo := module_directory() + "/.."

# Generate Talos cluster configuration files
gen:
    talhelper genconfig -c {{ repo }}/talos/talconfig.yaml -o {{ repo }}/talos/clusterconfig -s {{ repo }}/talos/talsecret.sops.yaml

# Encrypt the Talos secrets file using sops
encrypt:
    sops --config {{ repo }}/.sops.yaml -e -i {{ repo }}/talos/talsecret.sops.yaml

# Apply Talos configuration to the cluster nodes
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ repo }}"
    ./talos/apply.sh talos/talconfig.yaml

# Retrieve Kubernetes kubeconfig from the first Talos control-plane node
kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail

    config="{{ repo }}/talos/talconfig.yaml"
    talosconfig="{{ repo }}/talos/clusterconfig/talosconfig"
    output="{{ repo }}/talos/clusterconfig/kubeconfig"

    for bin in yq talosctl; do
      if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Error: $bin is required but not installed." >&2
        exit 1
      fi
    done

    if [[ ! -f "$talosconfig" ]]; then
      echo "Error: Talos config not found at $talosconfig. Run 'just talos gen' first." >&2
      exit 1
    fi

    node="$(yq -r '.nodes[] | select(.controlPlane == true) | .ipAddress' "$config" | head -n 1)"
    node="${node%%,*}"
    node="$(echo "$node" | xargs)"

    if [[ -z "$node" || "$node" == "null" ]]; then
      echo "Error: no control-plane node IP found in $config." >&2
      exit 1
    fi

    talosctl --talosconfig "$talosconfig" kubeconfig --nodes "$node" --endpoints "$node" "$output"
    echo "Wrote kubeconfig to $output"
