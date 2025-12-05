#!/bin/bash
set -eu

# =============================================================================
# Terraform GCP Infrastructure - 신규 프로젝트 생성 스크립트
# =============================================================================
# 사용법: ./create_project.sh <project_id> <project_name> <organization> <environment> <region_primary>
#
# 예시: ./create_project.sh my-game-prod game-prod myorg LIVE asia-northeast3
#
# 이 스크립트는:
# 1. proj-default-templet을 복사
# 2. 필수 설정 파일들의 값을 치환
# 3. 현재 브랜치에 commit
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

# Jenkins Credential ID (GCP 서비스 계정)
DEFAULT_JENKINS_CREDENTIAL_ID="delabs-terraform-admin"

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
# 크로스 플랫폼 sed 함수 (macOS/Linux 호환)
# =============================================================================
# macOS의 BSD sed는 -i '' 필요, Linux GNU sed는 -i만 사용
# -E 옵션으로 확장 정규식 사용 (\s, \d 등)
sedi() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "$@"
    else
        sed -i -E "$@"
    fi
}

# =============================================================================
# 파라미터 검증
# =============================================================================

if [ $# -lt 5 ]; then
    log_error "사용법: $0 <project_id> <project_name> <organization> <environment> <region_primary>"
    log_info "예시: $0 my-game-prod game-prod myorg LIVE asia-northeast3"
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
    JENKINS_CREDENTIAL_ID="${DEFAULT_JENKINS_CREDENTIAL_ID}"
else
    log_info "defaults.yaml에서 설정값 로드 중..."
    REMOTE_STATE_BUCKET=$(yq eval '.terraform.remote_state.bucket' "${CONFIG_FILE}")
    REMOTE_STATE_PROJECT=$(yq eval '.terraform.remote_state.project' "${CONFIG_FILE}")
    REMOTE_STATE_LOCATION=$(yq eval '.terraform.remote_state.location' "${CONFIG_FILE}")
    ORG_ID=$(yq eval '.gcp.org_id' "${CONFIG_FILE}")
    BILLING_ACCOUNT=$(yq eval '.gcp.billing_account' "${CONFIG_FILE}")
    JENKINS_CREDENTIAL_ID=$(yq eval '.jenkins.credential_id // "gcp-jenkins-service-account"' "${CONFIG_FILE}")
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
log_info "[1/3] root.hcl 치환 중..."
ROOT_HCL="${TARGET_DIR}/root.hcl"

# 플레이스홀더를 실제 값으로 치환
sedi "s|REPLACE_REMOTE_STATE_BUCKET|${REMOTE_STATE_BUCKET}|g" "${ROOT_HCL}"
sedi "s|REPLACE_MANAGEMENT_PROJECT_ID|${REMOTE_STATE_PROJECT}|g" "${ROOT_HCL}"
sedi "s|REPLACE_REMOTE_STATE_LOCATION|${REMOTE_STATE_LOCATION}|g" "${ROOT_HCL}"
sedi "s|REPLACE_ORG_ID|${ORG_ID}|g" "${ROOT_HCL}"
sedi "s|REPLACE_BILLING_ACCOUNT|${BILLING_ACCOUNT}|g" "${ROOT_HCL}"

log_success "root.hcl 치환 완료"

# -----------------------------------------------------------------------------
# 2. common.naming.tfvars
# -----------------------------------------------------------------------------
log_info "[2/3] common.naming.tfvars 치환 중..."
COMMON_TFVARS="${TARGET_DIR}/common.naming.tfvars"

# environment 값 변환 (LIVE -> live, QA -> qa, STG -> stg)
ENVIRONMENT_LOWER=$(echo "${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]')

# 기본 프로젝트 정보 치환
sedi "s|YOUR_PROJECT_ID|${PROJECT_ID}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_PROJECT_NAME|${PROJECT_NAME}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_ORGANIZATION|${ORGANIZATION}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_REGION_PRIMARY|${REGION_PRIMARY}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_REGION_BACKUP|${REGION_BACKUP}|g" "${COMMON_TFVARS}"

# Bootstrap 폴더 설정 치환
sedi "s|YOUR_FOLDER_PRODUCT|${PROJECT_ID}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_FOLDER_REGION|${REGION_PRIMARY}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_FOLDER_ENV|${ENVIRONMENT}|g" "${COMMON_TFVARS}"

# 관리 프로젝트 정보 치환
sedi "s|YOUR_MANAGEMENT_PROJECT_ID|${REMOTE_STATE_PROJECT}|g" "${COMMON_TFVARS}"
sedi "s|YOUR_MGMT_PROJECT_ID|${REMOTE_STATE_PROJECT}|g" "${COMMON_TFVARS}"

# 팀/조직 치환 (기본값으로 organization 사용)
sedi "s|YOUR_TEAM|${ORGANIZATION}-team|g" "${COMMON_TFVARS}"

log_success "common.naming.tfvars 치환 완료"

# -----------------------------------------------------------------------------
# 3. Jenkinsfile
# -----------------------------------------------------------------------------
log_info "[3/3] Jenkinsfile 치환 중..."
JENKINSFILE="${TARGET_DIR}/Jenkinsfile"

# TG_WORKING_DIR 플레이스홀더 치환
sedi "s|YOUR_FOLDER_ENV|${ENVIRONMENT}|g" "${JENKINSFILE}"
sedi "s|YOUR_PROJECT_ID|${PROJECT_ID}|g" "${JENKINSFILE}"

# Jenkins Credential ID 치환
sedi "s|YOUR_JENKINS_CREDENTIAL_ID|${JENKINS_CREDENTIAL_ID}|g" "${JENKINSFILE}"

log_success "Jenkinsfile 치환 완료"

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
- ENVIRONMENT: ${ENVIRONMENT}
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
log_warn "다음 단계 (수동 설정 필요):"
echo "  1. common.naming.tfvars 수정:"
echo "     - network_config.subnets: 프로젝트별 CIDR 설정"
echo "     - network_config.psc_endpoints: PSC Endpoint IP 설정"
echo "     - network_config.peering: VPC Peering 설정"
echo "     - vm_static_ips: VM 고정 IP 설정"
echo "     - dns_config: Private DNS 도메인 설정"
echo "     - vm_admin_config: VM 관리자 계정 설정"
echo ""
echo "  2. Jenkins Job 생성:"
echo "     - Script Path: environments/${ENVIRONMENT}/${PROJECT_ID}/Jenkinsfile"
echo ""
echo "  3. 초기 배포:"
echo "     - 00-project → 10-network → 12-dns → ... 순서로 apply"
echo ""
