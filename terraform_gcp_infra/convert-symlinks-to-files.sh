#!/bin/bash
# Convert locals.tf symlinks to actual files for Windows VSCode compatibility
# Usage: ./convert-symlinks-to-files.sh <project-path>
# Example: ./convert-symlinks-to-files.sh environments/prod/jsj-game-c

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <project-path>"
  echo "Example: $0 environments/prod/jsj-game-c"
  exit 1
fi

PROJECT_PATH="$1"
SOURCE_LOCALS="${PROJECT_PATH}/locals.tf"

if [ ! -f "$SOURCE_LOCALS" ]; then
  echo "Error: ${SOURCE_LOCALS} not found"
  exit 1
fi

echo "Converting symlinks to real files in ${PROJECT_PATH}..."

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
  if [ -L "$TARGET" ]; then
    # It's a symlink, replace with real file
    rm "$TARGET"
    cp "$SOURCE_LOCALS" "$TARGET"
    echo "✓ Converted $layer (symlink → file)"
  elif [ -f "$TARGET" ]; then
    # It's already a file, update it
    cp "$SOURCE_LOCALS" "$TARGET"
    echo "✓ Updated $layer (file → file)"
  else
    # Doesn't exist, create it
    if [ -d "${PROJECT_PATH}/${layer}" ]; then
      cp "$SOURCE_LOCALS" "$TARGET"
      echo "✓ Created $layer"
    else
      echo "⊘ Skipped $layer (directory not found)"
    fi
  fi
done

echo ""
echo "✅ Conversion completed!"
echo ""
echo "⚠️  Important: From now on, when you update the parent locals.tf,"
echo "   you must run this script again to sync all layers."
