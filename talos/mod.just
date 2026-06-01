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
