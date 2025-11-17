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
  awk -v key="${key}" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(key "[[:space:]]*=[[:space:]]*", "", line)
      sub(/#.*/, "", line)
      line = trim(line)
      if (line ~ /^"/) {
        sub(/^"/, "", line)
        sub(/"$/, "", line)
      }
      print line
      exit
    }
  ' "${file}"
}

read_list() {
  local file="$1"
  local key="$2"
  [[ -f "${file}" ]] || return 1
  awk -v key="${key}" '
    function extract(line) {
      while (match(line, /"([^"]+)"/, m)) {
        print m[1]
        line = substr(line, RSTART + RLENGTH)
      }
    }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      inlist = 1
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(key "[[:space:]]*=[[:space:]]*", "", line)
      if (line ~ /\[/) {
        sub(/^[^\[]*\[/, "", line)
      }
      extract(line)
      if (line ~ /\]/) {
        inlist = 0
      }
      next
    }
    inlist {
      line = $0
      extract(line)
      if (line ~ /\]/) {
        inlist = 0
      }
    }
  ' "${file}"
}

lookup_folder_from_bootstrap() {
  local product="$1"
  local region="$2"
  local env="$3"
  local bootstrap_dir="${REPO_ROOT}/bootstrap"
  [[ -d "${bootstrap_dir}" ]] || return 1
  [[ -f "${bootstrap_dir}/terraform.tfstate" ]] || return 1
  require_cmd "terraform"

  local expr result trimmed
  expr="output.folder_structure.value[\"${product}\"][\"${region}\"][\"${env}\"]"
  if result="$(TF_IN_AUTOMATION=1 terraform -chdir="${bootstrap_dir}" console <<EOF
${expr}
exit
EOF
)"; then
    trimmed="$(printf '%s\n' "${result}" | head -n1 | tr -d '"' | tr -d '\r')"
    trimmed="$(echo "${trimmed}" | xargs)"
    if [[ -n "${trimmed}" ]]; then
      echo "${trimmed}"
      return 0
    fi
  fi
  return 1
}

ENV_DIR="$(cd "${env_dir_arg}" 2>/dev/null && pwd || true)"
if [[ -z "${ENV_DIR}" || ! -d "${ENV_DIR}" ]]; then
  echo "[ERROR] Environment directory '${env_dir_arg}' not found." >&2
  exit 1
fi

COMMON_FILE="${ENV_DIR}/common.naming.tfvars"
ROOT_FILE="${ENV_DIR}/root.hcl"
PROJECT_TFVARS="${ENV_DIR}/00-project/terraform.tfvars"

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
