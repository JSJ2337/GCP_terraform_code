#!/usr/bin/env bash
set -euo pipefail

# GCP project guard for Terragrunt CI pipelines.
# Ensures projects are created/linked/moved before plan/apply,
# and removes blocking org/billing/lien settings before destroy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  gcp_project_guard.sh ensure <environment_dir>
  gcp_project_guard.sh cleanup <environment_dir>

Commands:
  ensure   Ensure the project exists, has billing enabled, resides in the expected folder/org,
           enables required APIs, and verifies Jenkins service account bindings.
  cleanup  Remove liens and prepare the project for deletion (used before destroy pipelines).

Arguments:
  <environment_dir>  Terragrunt environment root (e.g. terraform_gcp_infra/environments/LIVE/jsj-game-m)
USAGE
}

cmd="${1:-}"
env_dir_arg="${2:-}"

if [[ -z "${cmd}" || -z "${env_dir_arg}" ]]; then
  usage
  exit 1
fi

require_cmd() {
  local bin="${1}"
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "[ERROR] Required command '${bin}' not found on PATH." >&2
    exit 1
  fi
}

log() {
  local level="${1}"
  shift
  printf '[%s] %s\n' "${level}" "$*"
}

read_kv() {
  local file="$1"
  local key="$2"
  [[ -f "${file}" ]] || return 1
  "${PYTHON_BIN}" - "$file" "$key" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
pattern = re.compile(r'^\s*%s\s*=\s*(?:"([^"]+)"|([^\s#]+))' % re.escape(key), re.MULTILINE)
match = pattern.search(text)
if match:
    value = match.group(1) or match.group(2)
    print(value)
PY
}

read_list() {
  local file="$1"
  local key="$2"
  [[ -f "${file}" ]] || return 1
  "${PYTHON_BIN}" - "$file" "$key" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
pattern = re.compile(r'^\s*%s\s*=\s*\[(.*?)\]' % re.escape(key), re.S | re.M)
match = pattern.search(text)
if not match:
    sys.exit(0)
raw_list = "[" + match.group(1) + "]"
items = re.findall(r'"([^"]+)"', raw_list)
for item in items:
    print(item)
PY
}

lookup_folder_from_bootstrap() {
  local product="$1"
  local region="$2"
  local env="$3"
  local bootstrap_dir="${REPO_ROOT}/bootstrap"
  [[ -d "${bootstrap_dir}" ]] || return 1
  local state_file="${bootstrap_dir}/terraform.tfstate"
  [[ -f "${state_file}" ]] || return 1

  local value
  value="$("${PYTHON_BIN}" - "$state_file" "$product" "$region" "$env" <<'PY'
import json, sys
state_path, product, region, env = sys.argv[1:5]
try:
    with open(state_path, encoding="utf-8") as fp:
        data = json.load(fp)
    outputs = data.get("outputs", {})
    folder = outputs.get("folder_structure", {}).get("value", {})
    result = folder.get(product, {}).get(region, {}).get(env, "")
    if result:
        print(result)
except Exception:
    pass
PY
)"
  if [[ -n "${value}" ]]; then
    echo "${value}"
    return 0
  fi
  return 1
}

ensure_gcloud_auth() {
  if [[ -n "${GCLOUD_AUTHENTICATED:-}" ]]; then
    return
  fi
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    log INFO "Activating service account from GOOGLE_APPLICATION_CREDENTIALS"
    gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}" --quiet
    GCLOUD_AUTHENTICATED="true"
  else
    log WARN "GOOGLE_APPLICATION_CREDENTIALS not set; using default gcloud account."
  fi
}

ENV_DIR="$(cd "${env_dir_arg}" 2>/dev/null && pwd || true)"
if [[ -z "${ENV_DIR}" || ! -d "${ENV_DIR}" ]]; then
  echo "[ERROR] Environment directory '${env_dir_arg}' not found." >&2
  exit 1
fi

COMMON_FILE="${ENV_DIR}/common.naming.tfvars"
ROOT_FILE="${ENV_DIR}/root.hcl"
PROJECT_TFVARS="${ENV_DIR}/00-project/terraform.tfvars"

PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [[ -z "${PYTHON_BIN}" ]]; then
  echo "[ERROR] python3 (or python) not found on PATH." >&2
  exit 1
fi
require_cmd "gcloud"

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

ensure_metadata_loaded() {
  PROJECT_ID="${PROJECT_ID:-$(read_kv "${COMMON_FILE}" "project_id" || true)}"
  PROJECT_NAME="${PROJECT_NAME:-$(read_kv "${COMMON_FILE}" "project_name" || true)}"
  PROJECT_NAME="${PROJECT_NAME:-${PROJECT_ID}}"
  ORG_ID="${ORG_ID:-$(read_kv "${ROOT_FILE}" "org_id" || true)}"
  BILLING_ACCOUNT="${BILLING_ACCOUNT:-$(read_kv "${ROOT_FILE}" "billing_account" || true)}"

  # Folder resolution priority: explicit folder_id -> bootstrap structure -> org fallback.
  local raw_folder
  raw_folder="$(read_kv "${PROJECT_TFVARS}" "folder_id" || true)"
  if [[ "${raw_folder}" == "null" ]]; then
    raw_folder=""
  fi
  FOLDER_ID="${FOLDER_ID:-${raw_folder:-}}"

  # Fallback to bootstrap folder structure when folder_id is empty.
  if [[ -z "${FOLDER_ID}" ]]; then
    local prod region env
    prod="$(read_kv "${ROOT_FILE}" "folder_product" || read_kv "${PROJECT_TFVARS}" "folder_product" || echo "games")"
    region="$(read_kv "${ROOT_FILE}" "folder_region" || read_kv "${PROJECT_TFVARS}" "folder_region" || echo "kr-region")"
    env="$(read_kv "${ROOT_FILE}" "folder_env" || read_kv "${PROJECT_TFVARS}" "folder_env" || echo "LIVE")"

    local folder_lookup
    if folder_lookup="$(lookup_folder_from_bootstrap "${prod}" "${region}" "${env}")"; then
      FOLDER_ID="${folder_lookup}"
    fi
  fi

  # APIs defined in terraform.tfvars (one per line)
  if [[ -z "${APIS_LOADED:-}" ]]; then
    mapfile -t REQUIRED_APIS < <(read_list "${PROJECT_TFVARS}" "apis" || true)
    APIS_LOADED="true"
  fi

  if [[ -z "${PROJECT_ID}" ]]; then
    echo "[ERROR] project_id not found in ${COMMON_FILE}" >&2
    exit 1
  fi
  if [[ -z "${BILLING_ACCOUNT}" ]]; then
    echo "[ERROR] billing_account not found in ${ROOT_FILE}" >&2
    exit 1
  fi
}

get_parent_arg() {
  if [[ -n "${FOLDER_ID:-}" ]]; then
    printf -- '--folder=%s' "${FOLDER_ID}"
  elif [[ -n "${ORG_ID:-}" ]]; then
    printf -- '--organization=%s' "${ORG_ID}"
  else
    printf ''
  fi
}

project_exists() {
  gcloud projects describe "${PROJECT_ID}" --format="value(projectId)" >/dev/null 2>&1
}

current_parent() {
  gcloud projects describe "${PROJECT_ID}" --format="value(parent.type,parent.id)" 2>/dev/null || true
}

ensure_project_creation() {
  if project_exists; then
    log INFO "Project ${PROJECT_ID} already exists."
    return
  fi

  local parent_arg
  parent_arg="$(get_parent_arg)"
  log INFO "Creating project ${PROJECT_ID} (${PROJECT_NAME}) ${parent_arg}"
  if [[ -n "${parent_arg}" ]]; then
    gcloud projects create "${PROJECT_ID}" --name="${PROJECT_NAME}" "${parent_arg}"
  else
    log WARN "No folder/org parent detected. Creating project without explicit parent."
    gcloud projects create "${PROJECT_ID}" --name="${PROJECT_NAME}"
  fi
}

ensure_project_parent() {
  [[ -n "${FOLDER_ID:-}" ]] || return
  local expected="folder/${FOLDER_ID##*/}"
  local parent
  parent="$(current_parent)"
  if [[ "${parent}" == *"${expected}"* ]]; then
    log INFO "Project ${PROJECT_ID} already under folder ${FOLDER_ID}."
    return
  fi

  log INFO "Moving project ${PROJECT_ID} to folder ${FOLDER_ID}"
  gcloud beta resource-manager projects move "${PROJECT_ID}" --folder="${FOLDER_ID}"
}

ensure_billing() {
  local billing_enabled
  billing_enabled="$(gcloud beta billing projects describe "${PROJECT_ID}" --format="value(billingEnabled)" 2>/dev/null || echo "False")"
  if [[ "${billing_enabled}" == "True" ]]; then
    log INFO "Billing already enabled for ${PROJECT_ID}."
    return
  fi
  log INFO "Linking billing account ${BILLING_ACCOUNT} to ${PROJECT_ID}"
  gcloud beta billing projects link "${PROJECT_ID}" --billing-account="${BILLING_ACCOUNT}"
}

discover_sa_email() {
  if [[ -n "${SA_EMAIL:-}" ]]; then
    return
  fi
  if [[ -n "${JENKINS_SA_EMAIL:-}" ]]; then
    SA_EMAIL="${JENKINS_SA_EMAIL}"
    return
  fi
  if command -v terraform >/dev/null 2>&1 && [[ -d "${REPO_ROOT}/bootstrap" ]]; then
    SA_EMAIL="$(terraform -chdir="${REPO_ROOT}/bootstrap" output -raw jenkins_service_account_email 2>/dev/null || true)"
  fi
}

ensure_org_binding() {
  local role="$1"
  [[ -n "${ORG_ID:-}" && -n "${SA_EMAIL:-}" ]] || return
  local member="serviceAccount:${SA_EMAIL}"
  local has_binding
  has_binding="$(gcloud organizations get-iam-policy "${ORG_ID}" \
    --flatten="bindings[]" \
    --filter="bindings.role=${role} AND bindings.members=${member}" \
    --format="value(bindings.role)" 2>/dev/null || true)"
  if [[ -n "${has_binding}" ]]; then
    log INFO "Org binding ${role} already present for ${SA_EMAIL}."
    return
  fi
  log INFO "Adding org binding ${role} for ${SA_EMAIL}"
  gcloud organizations add-iam-policy-binding "${ORG_ID}" \
    --member="${member}" \
    --role="${role}"
}

ensure_billing_binding() {
  [[ -n "${BILLING_ACCOUNT:-}" && -n "${SA_EMAIL:-}" ]] || return
  local member="serviceAccount:${SA_EMAIL}"
  local role="roles/billing.user"
  local has_binding
  has_binding="$(gcloud beta billing accounts get-iam-policy "${BILLING_ACCOUNT}" \
    --flatten="bindings[]" \
    --filter="bindings.role=${role} AND bindings.members=${member}" \
    --format="value(bindings.role)" 2>/dev/null || true)"
  if [[ -n "${has_binding}" ]]; then
    log INFO "Billing binding already present for ${SA_EMAIL}."
    return
  fi
  log INFO "Adding billing binding ${role} for ${SA_EMAIL}"
  gcloud beta billing accounts add-iam-policy-binding "${BILLING_ACCOUNT}" \
    --member="${member}" \
    --role="${role}"
}

ensure_project_binding() {
  [[ -n "${SA_EMAIL:-}" ]] || return
  local member="serviceAccount:${SA_EMAIL}"
  local role="roles/editor"
  local has_binding
  has_binding="$(gcloud projects get-iam-policy "${PROJECT_ID}" \
    --flatten="bindings[]" \
    --filter="bindings.role=${role} AND bindings.members=${member}" \
    --format="value(bindings.role)" 2>/dev/null || true)"
  if [[ -n "${has_binding}" ]]; then
    log INFO "Project binding already present for ${SA_EMAIL}."
    return
  fi
  log INFO "Adding project binding ${role} for ${SA_EMAIL}"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="${member}" \
    --role="${role}"
}

enable_apis() {
  [[ "${#REQUIRED_APIS[@]}" -gt 0 ]] || return
  log INFO "Enabling ${#REQUIRED_APIS[@]} APIs for ${PROJECT_ID}"
  gcloud services enable "${REQUIRED_APIS[@]}" --project="${PROJECT_ID}"
}

ensure_phase() {
  ensure_metadata_loaded
  ensure_gcloud_auth
  ensure_project_creation
  ensure_project_parent
  ensure_billing
  discover_sa_email || true
  ensure_org_binding "roles/resourcemanager.projectCreator" || true
  ensure_org_binding "roles/editor" || true
  ensure_billing_binding || true
  ensure_project_binding || true
  enable_apis || true
  log INFO "Project guard ensure phase completed for ${PROJECT_ID}."
}

cleanup_liens() {
  log INFO "Checking liens for ${PROJECT_ID}"
  local liens
  liens="$(gcloud alpha resource-manager liens list --project="${PROJECT_ID}" --format="value(name)" 2>/dev/null || true)"
  if [[ -z "${liens}" ]]; then
    log INFO "No liens found for ${PROJECT_ID}."
    return
  fi
  while read -r lien; do
    [[ -n "${lien}" ]] || continue
    log INFO "Removing lien ${lien}"
    gcloud alpha resource-manager liens delete "${lien}"
  done <<<"${liens}"
}

cleanup_phase() {
  ensure_metadata_loaded
  ensure_gcloud_auth
  if ! project_exists; then
    log INFO "Project ${PROJECT_ID} does not exist. Nothing to cleanup."
    return
  fi
  cleanup_liens || true
  log INFO "Cleanup phase completed for ${PROJECT_ID}."
}

case "${cmd}" in
  ensure)
    ensure_phase
    ;;
  cleanup)
    cleanup_phase
    ;;
  *)
    usage
    exit 1
    ;;
esac
