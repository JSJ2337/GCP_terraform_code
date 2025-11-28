#!/bin/bash
set -eu

# =============================================================================
# Terraform GCP Infrastructure - 신규 프로젝트 생성 스크립트
# =============================================================================
# 사용법: ./create_project.sh <project_id> <project_name> <organization> <environment> <region_primary>
#
# 예시: ./create_project.sh jsj-game-n game-n jsj LIVE asia-northeast3
#
# 이 스크립트는:
# 1. proj-default-templet을 복사
# 2. 필수 설정 파일들의 값을 치환
# 3. 현재 브랜치에 commit
# 4. GitHub에 push
# =============================================================================

# =============================================================================
# 설정값 (Configuration)
# =============================================================================
# 이 섹션의 값들을 수정하여 환경에 맞게 조정할 수 있습니다.

# 기본 리전 설정
DEFAULT_REGION_BACKUP="asia-northeast1"  # 도쿄

# Terraform Remote State 설정 (yq 없을 때 사용될 기본값)
DEFAULT_REMOTE_STATE_BUCKET="jsj-terraform-state-prod"
DEFAULT_REMOTE_STATE_PROJECT="jsj-system-mgmt"
DEFAULT_REMOTE_STATE_LOCATION="US"

# GCP 조직 및 빌링 설정 (yq 없을 때 사용될 기본값)
DEFAULT_ORG_ID="REDACTED_ORG_ID"
DEFAULT_BILLING_ACCOUNT="REDACTED_BILLING_ACCOUNT"

# 디렉토리 및 파일명 설정
CONFIG_FILE_NAME="configs/defaults.yaml"
TEMPLATE_DIR_NAME="proj-default-templet"
ENVIRONMENTS_DIR_NAME="environments"

# Terraform GCP Infra 디렉토리 설정 (Jenkinsfile에서 사용)
TF_GCP_INFRA_DIR_NAME="terraform_gcp_infra"

# =============================================================================
# 색상 정의
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# 파라미터 검증
# =============================================================================

if [ $# -lt 5 ]; then
    log_error "사용법: $0 <project_id> <project_name> <organization> <environment> <region_primary>"
    log_info "예시: $0 jsj-game-n game-n jsj LIVE asia-northeast3"
    log_info "환경: LIVE, QA, STG"
    exit 1
fi

PROJECT_ID="$1"
PROJECT_NAME="$2"
ORGANIZATION="$3"
ENVIRONMENT="$4"
REGION_PRIMARY="$5"
REGION_BACKUP="${6:-${DEFAULT_REGION_BACKUP}}"  # 기본값: 설정 섹션 참조

# 환경 검증
if [[ ! "$ENVIRONMENT" =~ ^(LIVE|QA|STG)$ ]]; then
    log_error "환경은 LIVE, QA, STG 중 하나여야 합니다: $ENVIRONMENT"
    exit 1
fi

log_info "신규 프로젝트 생성 시작"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PROJECT_ID     : ${PROJECT_ID}"
echo "  PROJECT_NAME   : ${PROJECT_NAME}"
echo "  ORGANIZATION   : ${ORGANIZATION}"
echo "  ENVIRONMENT    : ${ENVIRONMENT}"
echo "  REGION_PRIMARY : ${REGION_PRIMARY}"
echo "  REGION_BACKUP  : ${REGION_BACKUP}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
# 디렉토리 및 파일 경로 설정
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/${CONFIG_FILE_NAME}"
SOURCE_TEMPLATE="${REPO_ROOT}/${TEMPLATE_DIR_NAME}"
TARGET_DIR="${REPO_ROOT}/${ENVIRONMENTS_DIR_NAME}/${ENVIRONMENT}/${PROJECT_ID}"

log_info "작업 디렉토리: ${REPO_ROOT}"
log_info "생성 위치: ${ENVIRONMENTS_DIR_NAME}/${ENVIRONMENT}/${PROJECT_ID}"

# =============================================================================
# defaults.yaml 로드 (yq 필요)
# =============================================================================

if ! command -v yq &> /dev/null; then
    log_warn "yq가 설치되어 있지 않습니다. 기본값을 사용합니다."
    REMOTE_STATE_BUCKET="${DEFAULT_REMOTE_STATE_BUCKET}"
    REMOTE_STATE_PROJECT="${DEFAULT_REMOTE_STATE_PROJECT}"
    REMOTE_STATE_LOCATION="${DEFAULT_REMOTE_STATE_LOCATION}"
    ORG_ID="${DEFAULT_ORG_ID}"
    BILLING_ACCOUNT="${DEFAULT_BILLING_ACCOUNT}"
else
    log_info "defaults.yaml에서 설정값 로드 중..."
    REMOTE_STATE_BUCKET=$(yq eval '.terraform.remote_state.bucket' "${CONFIG_FILE}")
    REMOTE_STATE_PROJECT=$(yq eval '.terraform.remote_state.project' "${CONFIG_FILE}")
    REMOTE_STATE_LOCATION=$(yq eval '.terraform.remote_state.location' "${CONFIG_FILE}")
    ORG_ID=$(yq eval '.gcp.org_id' "${CONFIG_FILE}")
    BILLING_ACCOUNT=$(yq eval '.gcp.billing_account' "${CONFIG_FILE}")
fi

log_success "설정값 로드 완료"

# =============================================================================
# 사전 검증
# =============================================================================

log_info "사전 검증 수행 중..."

# 1. 소스 템플릿 존재 확인
if [ ! -d "${SOURCE_TEMPLATE}" ]; then
    log_error "템플릿 디렉토리를 찾을 수 없습니다: ${SOURCE_TEMPLATE}"
    exit 1
fi

# 2. 타겟 디렉토리 중복 확인
if [ -d "${TARGET_DIR}" ]; then
    log_error "프로젝트가 이미 존재합니다: ${TARGET_DIR}"
    log_info "기존 프로젝트를 삭제하거나 다른 이름을 사용하세요."
    exit 1
fi

# 3. Git 저장소 확인
if ! git -C "${REPO_ROOT}" rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Git 저장소가 아닙니다: ${REPO_ROOT}"
    exit 1
fi

log_success "사전 검증 완료"

# =============================================================================
# 프로젝트 생성
# =============================================================================

log_info "템플릿 복사 중: ${SOURCE_TEMPLATE} → ${TARGET_DIR}"
cp -r "${SOURCE_TEMPLATE}" "${TARGET_DIR}"
log_success "템플릿 복사 완료"

# =============================================================================
# 필수 파일 치환
# =============================================================================

log_info "설정 파일 치환 시작..."

# -----------------------------------------------------------------------------
# 1. root.hcl
# -----------------------------------------------------------------------------
log_info "[1/4] root.hcl 치환 중..."
ROOT_HCL="${TARGET_DIR}/root.hcl"

sed -i "s|remote_state_bucket\s*=\s*\"[^\"]*\"|remote_state_bucket   = \"${REMOTE_STATE_BUCKET}\"|g" "${ROOT_HCL}"
sed -i "s|remote_state_project\s*=\s*\"[^\"]*\"|remote_state_project  = \"${REMOTE_STATE_PROJECT}\"|g" "${ROOT_HCL}"
sed -i "s|remote_state_location\s*=\s*\"[^\"]*\"|remote_state_location = \"${REMOTE_STATE_LOCATION}\"|g" "${ROOT_HCL}"
sed -i "s|project_state_prefix\s*=\s*\"[^\"]*\"|project_state_prefix  = \"${PROJECT_ID}\"|g" "${ROOT_HCL}"
sed -i "s|org_id\s*=\s*\"[^\"]*\"|org_id          = \"${ORG_ID}\"|g" "${ROOT_HCL}"
sed -i "s|billing_account\s*=\s*\"[^\"]*\"|billing_account = \"${BILLING_ACCOUNT}\"|g" "${ROOT_HCL}"

log_success "root.hcl 치환 완료"

# -----------------------------------------------------------------------------
# 2. common.naming.tfvars
# -----------------------------------------------------------------------------
log_info "[2/4] common.naming.tfvars 치환 중..."
COMMON_TFVARS="${TARGET_DIR}/common.naming.tfvars"

sed -i "s|^project_id\s*=\s*\"[^\"]*\"|project_id     = \"${PROJECT_ID}\"|g" "${COMMON_TFVARS}"
sed -i "s|^project_name\s*=\s*\"[^\"]*\"|project_name   = \"${PROJECT_NAME}\"|g" "${COMMON_TFVARS}"
sed -i "s|^organization\s*=\s*\"[^\"]*\"|organization   = \"${ORGANIZATION}\"|g" "${COMMON_TFVARS}"
sed -i "s|^region_primary\s*=\s*\"[^\"]*\"|region_primary = \"${REGION_PRIMARY}\"|g" "${COMMON_TFVARS}"
sed -i "s|^region_backup\s*=\s*\"[^\"]*\"|region_backup  = \"${REGION_BACKUP}\"|g" "${COMMON_TFVARS}"

log_success "common.naming.tfvars 치환 완료"

# -----------------------------------------------------------------------------
# 3. Jenkinsfile
# -----------------------------------------------------------------------------
log_info "[3/4] Jenkinsfile 치환 중..."
JENKINSFILE="${TARGET_DIR}/Jenkinsfile"

# TG_WORKING_DIR 패턴 치환 (LIVE, QA, STG 모두 대응)
sed -i "s|TG_WORKING_DIR = '${TF_GCP_INFRA_DIR_NAME}/${ENVIRONMENTS_DIR_NAME}/[^/]*/[^']*'|TG_WORKING_DIR = '${TF_GCP_INFRA_DIR_NAME}/${ENVIRONMENTS_DIR_NAME}/${ENVIRONMENT}/${PROJECT_ID}'|g" "${JENKINSFILE}"

log_success "Jenkinsfile 치환 완료"

# -----------------------------------------------------------------------------
# 4. 50-workloads/terraform.tfvars - VM/IG 이름 접두사 치환
# -----------------------------------------------------------------------------
log_info "[4/4] 50-workloads/terraform.tfvars 치환 중..."
WORKLOADS_TFVARS="${TARGET_DIR}/50-workloads/terraform.tfvars"

# VM 및 Instance Group 이름의 "jsj-" 접두사를 organization으로 치환
# 예: "jsj-lobby-01" → "myorg-lobby-01", ["jsj-web-01"] → ["myorg-web-01"]
sed -i "s|\"jsj-|\"${ORGANIZATION}-|g" "${WORKLOADS_TFVARS}"

log_success "50-workloads/terraform.tfvars 치환 완료"

# =============================================================================
# Git 작업
# =============================================================================

log_info "Git 커밋 중..."

cd "${REPO_ROOT}"

# 현재 브랜치 확인
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log_info "현재 브랜치: ${CURRENT_BRANCH}"

# 파일 추가
git add "${ENVIRONMENTS_DIR_NAME}/${ENVIRONMENT}/${PROJECT_ID}"

# 커밋
git commit -m "feat: ${PROJECT_ID} 프로젝트 생성

- proj-default-templet 기반으로 신규 프로젝트 생성
- PROJECT_ID: ${PROJECT_ID}
- PROJECT_NAME: ${PROJECT_NAME}
- ORGANIZATION: ${ORGANIZATION}
- REGION: ${REGION_PRIMARY}

🤖 Generated with create_project.sh"

log_success "Git 커밋 완료"

# =============================================================================
# 완료
# =============================================================================

echo ""
log_success "프로젝트 생성 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  프로젝트 위치: ${TARGET_DIR}"
echo "  Git 브랜치: ${CURRENT_BRANCH}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "다음 단계:"
echo "  1. Jenkins에서 terraform-deploy-${PROJECT_ID} Job 생성"
echo "  2. 초기 배포: 00-project → 10-network → ... 순서로 apply"
echo ""
