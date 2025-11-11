#!/usr/bin/env bash
set -euo pipefail

# Helper script to run Terragrunt commands across all prod template layers in order.
# Usage: ./run_terragrunt_stack.sh <command>
# Example: ./run_terragrunt_stack.sh plan
# Commands are forwarded to `terragrunt run --all` (requires terragrunt ≥0.93 on PATH).

TG_CMD="${1:-}"
if [[ -z "$TG_CMD" ]]; then
  echo "Usage: $0 <terragrunt-command> [additional args...]" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/environments/LIVE/proj-default-templet"

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Expected directory $ROOT_DIR not found." >&2
  exit 1
fi

# Ensure terragrunt is available
if ! command -v terragrunt &>/dev/null; then
  echo "terragrunt binary not found on PATH." >&2
  exit 1
fi

# Forward all arguments to Terragrunt's new run command
cd "$ROOT_DIR"
terragrunt run --all "$@"
