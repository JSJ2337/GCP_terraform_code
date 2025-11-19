#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GCP 프로젝트 가드 스크립트 (Terragrunt CI 파이프라인용)
# =============================================================================
# Terragrunt plan/apply 전에 프로젝트가 생성/연결/이동되었는지 확인하고,
# destroy 전에 차단 설정(org/billing/lien)을 제거합니다.
#
# 주요 기능:
# - ensure: 프로젝트 생성, 빌링 활성화, 폴더 배치, API 활성화, IAM 바인딩
# - cleanup: Lien 제거, 프로젝트 삭제 준비
# =============================================================================

# =============================================================================
# 설정값 (Configuration)
# =============================================================================
# 이 섹션의 값들을 수정하여 환경에 맞게 조정할 수 있습니다.

# Bootstrap 디렉토리 설정
BOOTSTRAP_DIR_NAME="bootstrap"

# 폴더 구조 기본값 (bootstrap에서 찾지 못했을 때 사용)
DEFAULT_FOLDER_PRODUCT="games"      # 제품/서비스 구분
DEFAULT_FOLDER_REGION="kr-region"   # 리전 구분
DEFAULT_FOLDER_ENV="LIVE"           # 환경 구분 (LIVE/QA/STG)

# IAM 역할 설정
ROLE_ORG_PROJECT_CREATOR="roles/resourcemanager.projectCreator"  # 프로젝트 생성 권한
ROLE_ORG_EDITOR="roles/editor"                                   # 조직 편집 권한
ROLE_BILLING_USER="roles/billing.user"                           # 빌링 사용자 권한
ROLE_PROJECT_EDITOR="roles/editor"                               # 프로젝트 편집 권한

# =============================================================================
# 경로 설정
# =============================================================================

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

# =============================================================================
# 유틸리티 함수
# =============================================================================

# 필수 커맨드 확인
require_cmd() {
  local bin="${1}"
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "[ERROR] Required command '${bin}' not found on PATH." >&2
    exit 1
  fi
}

# 로그 출력
log() {
  local level="${1}"
  shift
  printf '[%s] %s\n' "${level}" "$*"
}

# tfvars/hcl 파일에서 key=value 읽기
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

# tfvars 파일에서 리스트 값 읽기 (예: apis = ["api1", "api2"])
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

# Bootstrap terraform state에서 폴더 ID 조회
lookup_folder_from_bootstrap() {
  local product="$1"
  local region="$2"
  local env="$3"
  local bootstrap_dir="${REPO_ROOT}/${BOOTSTRAP_DIR_NAME}"
  [[ -d "${bootstrap_dir}" ]] || return 1
  local state_file="${bootstrap_dir}/terraform.tfstate"
  [[ -f "${state_file}" ]] || return 1

  local value
  value="$(${PYTHON_BIN} - "$state_file" "$product" "$region" "$env" <<'PY'
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

# gcloud 인증 확인 (서비스 계정 또는 기본 계정)
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

# =============================================================================
# 메타데이터 로드
# =============================================================================

# tfvars/hcl 파일에서 프로젝트 메타데이터 로드
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
    prod="$(read_kv "${ROOT_FILE}" "folder_product" || read_kv "${PROJECT_TFVARS}" "folder_product" || echo "${DEFAULT_FOLDER_PRODUCT}")"
    region="$(read_kv "${ROOT_FILE}" "folder_region" || read_kv "${PROJECT_TFVARS}" "folder_region" || echo "${DEFAULT_FOLDER_REGION}")"
    env="$(read_kv "${ROOT_FILE}" "folder_env" || read_kv "${PROJECT_TFVARS}" "folder_env" || echo "${DEFAULT_FOLDER_ENV}")"

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

# =============================================================================
# GCP 프로젝트 관리 함수
# =============================================================================

# 프로젝트 부모(폴더 또는 조직) 인자 생성
get_parent_arg() {
  if [[ -n "${FOLDER_ID:-}" ]]; then
    printf -- '--folder=%s' "${FOLDER_ID}"
  elif [[ -n "${ORG_ID:-}" ]]; then
    printf -- '--organization=%s' "${ORG_ID}"
  else
    printf ''
  fi
}

# 프로젝트 존재 여부 확인
project_exists() {
  gcloud projects describe "${PROJECT_ID}" --format="value(projectId)" >/dev/null 2>&1
}

# 현재 프로젝트의 부모(폴더/조직) 조회
current_parent() {
  gcloud projects describe "${PROJECT_ID}" --format="value(parent.type,parent.id)" 2>/dev/null || true
}

# 프로젝트 생성 (없을 경우에만)
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

# 프로젝트를 지정된 폴더로 이동
ensure_project_parent() {
  [[ -n "${FOLDER_ID:-}" ]] || return 0
  local expected="folder/${FOLDER_ID##*/}"
  local parent
  parent="$(current_parent)"
  if [[ "${parent}" == *"${expected}"* ]]; then
    log INFO "Project ${PROJECT_ID} already under folder ${FOLDER_ID}."
    return
  fi

  log INFO "Moving project ${PROJECT_ID} to folder ${FOLDER_ID}"
  if ! gcloud beta resource-manager projects move "${PROJECT_ID}" --folder="${FOLDER_ID}"; then
    log WARN "Failed to move ${PROJECT_ID} into folder ${FOLDER_ID}. Please adjust manually if needed."
  fi
}

# 프로젝트에 빌링 계정 연결
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

# =============================================================================
# IAM 바인딩 함수
# =============================================================================

# Jenkins 서비스 계정 이메일 자동 검색
discover_sa_email() {
  if [[ -n "${SA_EMAIL:-}" ]]; then
    return
  fi
  if [[ -n "${JENKINS_SA_EMAIL:-}" ]]; then
    SA_EMAIL="${JENKINS_SA_EMAIL}"
    return
  fi
  if command -v terraform >/dev/null 2>&1 && [[ -d "${REPO_ROOT}/${BOOTSTRAP_DIR_NAME}" ]]; then
    SA_EMAIL="$(terraform -chdir="${REPO_ROOT}/${BOOTSTRAP_DIR_NAME}" output -raw jenkins_service_account_email 2>/dev/null || true)"
  fi
}

# 조직 레벨 IAM 바인딩 추가
ensure_org_binding() {
  local role="$1"
  [[ -n "${ORG_ID:-}" && -n "${SA_EMAIL:-}" ]] || return 0
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
  if ! gcloud organizations add-iam-policy-binding "${ORG_ID}" \
    --member="${member}" \
    --role="${role}"; then
    log WARN "Failed to add org binding ${role} for ${SA_EMAIL}. Check permissions or apply manually."
  fi
}

# 빌링 계정 IAM 바인딩 추가
ensure_billing_binding() {
  [[ -n "${BILLING_ACCOUNT:-}" && -n "${SA_EMAIL:-}" ]] || return 0
  local member="serviceAccount:${SA_EMAIL}"
  local role="${ROLE_BILLING_USER}"
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
  if ! gcloud beta billing accounts add-iam-policy-binding "${BILLING_ACCOUNT}" \
    --member="${member}" \
    --role="${role}"; then
    log WARN "Failed to add billing binding for ${SA_EMAIL}. Check permissions or apply manually."
  fi
}

# 프로젝트 레벨 IAM 바인딩 추가
ensure_project_binding() {
  [[ -n "${SA_EMAIL:-}" ]] || return 0
  local member="serviceAccount:${SA_EMAIL}"
  local role="${ROLE_PROJECT_EDITOR}"
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
  if ! gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="${member}" \
    --role="${role}"; then
    log WARN "Failed to add project binding for ${SA_EMAIL}. Check permissions or apply manually."
  fi
}

# 필수 GCP API 활성화
enable_apis() {
  [[ "${#REQUIRED_APIS[@]}" -gt 0 ]] || return 0
  log INFO "Enabling ${#REQUIRED_APIS[@]} APIs for ${PROJECT_ID}"
  gcloud services enable "${REQUIRED_APIS[@]}" --project="${PROJECT_ID}"
}

# =============================================================================
# 메인 실행 단계
# =============================================================================

# Ensure 단계: 프로젝트 생성 및 설정
ensure_phase() {
  ensure_metadata_loaded
  ensure_gcloud_auth
  ensure_project_creation
  ensure_project_parent
  ensure_billing
  discover_sa_email || true
  ensure_org_binding "${ROLE_ORG_PROJECT_CREATOR}" || true
  ensure_org_binding "${ROLE_ORG_EDITOR}" || true
  ensure_billing_binding || true
  ensure_project_binding || true
  enable_apis || true
  log INFO "Project guard ensure phase completed for ${PROJECT_ID}."
}

# Lien 제거 (프로젝트 삭제 차단 해제)
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

# Cleanup 단계: 프로젝트 삭제 준비
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
