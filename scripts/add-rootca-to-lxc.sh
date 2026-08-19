#!/bin/bash
# Script to add root CA certificate to LXC containers
# Usage: ./add-rootca-to-lxc.sh <container-name>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <container-name>"
    echo "Example: $0 grafana"
    exit 1
fi

CONTAINER_NAME=$1
ROOT_CA_PATH="/home/jdiekhoff/_src/homeserver/certs/rootCA.crt"
TARGET_PATH="/usr/local/share/ca-certificates/rootCA.crt"

# Check if container exists
if ! pct list | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container '$CONTAINER_NAME' not found"
    exit 1
fi

# Check if root CA file exists
if [ ! -f "$ROOT_CA_PATH" ]; then
    echo "Error: Root CA file not found at $ROOT_CA_PATH"
    exit 1
fi

echo "Copying root CA certificate to container '$CONTAINER_NAME'..."
pct push "$CONTAINER_NAME" "$ROOT_CA_PATH" "$TARGET_PATH"

echo "Updating certificate store in container..."
pct exec "$CONTAINER_NAME" -- update-ca-certificates

echo "Root CA certificate has been added to container '$CONTAINER_NAME'"
echo "You may need to restart services in the container for the changes to take effect."
