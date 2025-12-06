#!/bin/bash

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Please install it first."
    exit 1
fi

# Check if YAML file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <yaml-file>"
    exit 1
fi

YAML_FILE="$1"

# Check if file exists
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: File '$YAML_FILE' not found"
    exit 1
fi

# Extract cluster name
CLUSTER_NAME=$(yq -r '.clusterName' "$YAML_FILE")

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
    echo "Error: clusterName not found in YAML file"
    exit 1
fi

echo "Processing cluster: $CLUSTER_NAME"
echo "---"

# Get the number of nodes
NODE_COUNT=$(yq -r '.nodes | length' "$YAML_FILE")

# Iterate through each node
for i in $(seq 0 $((NODE_COUNT - 1))); do
    HOSTNAME=$(yq -r ".nodes[$i].hostname" "$YAML_FILE")
    IP_ADDRESSES=$(yq -r ".nodes[$i].ipAddress" "$YAML_FILE")

    if [ -z "$HOSTNAME" ] || [ "$HOSTNAME" = "null" ]; then
        echo "Warning: Skipping node $i - no hostname found"
        continue
    fi

    if [ -z "$IP_ADDRESSES" ] || [ "$IP_ADDRESSES" = "null" ]; then
        echo "Warning: Skipping node $HOSTNAME - no IP address found"
        continue
    fi

    CONFIG_FILE="talos/clusterconfig/${CLUSTER_NAME}-${HOSTNAME}.yaml"

    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Warning: Config file '$CONFIG_FILE' not found, skipping node $HOSTNAME"
        continue
    fi

    echo "Processing nodes: $HOSTNAME"

    # Split IP addresses by comma and process each
    IFS=',' read -ra IP_ARRAY <<< "$IP_ADDRESSES"
    for IP in "${IP_ARRAY[@]}"; do
        # Trim whitespace
        IP=$(echo "$IP" | xargs)

        echo "  Applying config to IP: $IP"
        talosctl apply-config --insecure --nodes "$IP" --file "$CONFIG_FILE"

        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully applied config to $IP"
        else
            echo "  ✗ Failed to apply config to $IP"
        fi
    done

    echo "---"
done

echo "Done!"
