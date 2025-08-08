#!/bin/bash
set -e

# This script runs a locally built container with proper volume mounting

# Check if an image name is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <image_name> [additional docker run options]"
  echo "Example: $0 iv-cbv-payroll-app:latest"
  exit 1
fi

IMAGE_NAME=$1
shift

# Create directories if they don't exist
mkdir -p "$(pwd)/tmp"
mkdir -p "$(pwd)/log"

# Run the container with proper volume mounting
docker run \
  --mount type=bind,source="$(pwd)/tmp",target=/rails/tmp \
  --mount type=bind,source="$(pwd)/log",target=/rails/log \
  --publish 3000:3000 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e RAILS_SERVE_STATIC_FILES=true \
  "$@" \
  "$IMAGE_NAME"

echo "Container started with /rails/tmp and /rails/log properly mounted"