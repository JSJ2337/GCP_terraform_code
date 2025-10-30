#!/bin/bash
# Sync locals.tf from parent to all layer directories
# Usage: ./sync-locals.sh <project-path>
# Example: ./sync-locals.sh environments/prod/proj-default-templet

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <project-path>"
  echo "Example: $0 environments/prod/proj-default-templet"
  exit 1
fi

PROJECT_PATH="$1"
SOURCE_LOCALS="${PROJECT_PATH}/locals.tf"

if [ ! -f "$SOURCE_LOCALS" ]; then
  echo "Error: ${SOURCE_LOCALS} not found"
  exit 1
fi

echo "Syncing locals.tf from ${SOURCE_LOCALS} to all layers..."

LAYERS=(
  "00-project"
  "10-network"
  "20-storage"
  "30-security"
  "40-observability"
  "50-workloads"
  "60-database"
  "70-loadbalancer"
)

for layer in "${LAYERS[@]}"; do
  TARGET="${PROJECT_PATH}/${layer}/locals.tf"
  if [ -d "${PROJECT_PATH}/${layer}" ]; then
    cp -f "$SOURCE_LOCALS" "$TARGET"
    echo "✓ Copied to ${layer}"
  else
    echo "⊘ Skipped ${layer} (directory not found)"
  fi
done

echo ""
echo "✅ Sync completed!"
echo ""
echo "Note: Run this script whenever you update the parent locals.tf"
