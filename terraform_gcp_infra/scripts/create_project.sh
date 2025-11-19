#!/bin/bash
set -eu

# =============================================================================
# Terraform GCP Infrastructure - 신규 프로젝트 생성 스크립트
# =============================================================================
# 사용법: ./create_project.sh <project_id> <project_name> <organization> <region_primary>
#
# 예시: ./create_project.sh jsj-game-n game-n jsj asia-northeast3
#
# 이 스크립트는:
# 1. proj-default-templet을 복사
# 2. 필수 설정 파일들의 값을 치환
# 3. Git branch 생성 및 commit
# 4. (선택) Pull Request 생성
# =============================================================================

# 색상 정의
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

if [ $# -lt 4 ]; then
    log_error "사용법: $0 <project_id> <project_name> <organization> <region_primary>"
    log_info "예시: $0 jsj-game-n game-n jsj asia-northeast3"
    exit 1
fi

PROJECT_ID="$1"
PROJECT_NAME="$2"
ORGANIZATION="$3"
REGION_PRIMARY="$4"
REGION_BACKUP="${5:-asia-northeast1}"  # 기본값: 도쿄

log_info "신규 프로젝트 생성 시작"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PROJECT_ID     : ${PROJECT_ID}"
echo "  PROJECT_NAME   : ${PROJECT_NAME}"
echo "  ORGANIZATION   : ${ORGANIZATION}"
echo "  REGION_PRIMARY : ${REGION_PRIMARY}"
echo "  REGION_BACKUP  : ${REGION_BACKUP}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
# 디렉토리 및 파일 경로 설정
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/configs/defaults.yaml"
SOURCE_TEMPLATE="${REPO_ROOT}/proj-default-templet"
TARGET_DIR="${REPO_ROOT}/environments/LIVE/${PROJECT_ID}"

log_info "작업 디렉토리: ${REPO_ROOT}"

# =============================================================================
# defaults.yaml 로드 (yq 필요)
# =============================================================================

if ! command -v yq &> /dev/null; then
    log_warn "yq가 설치되어 있지 않습니다. 기본값을 사용합니다."
    REMOTE_STATE_BUCKET="jsj-terraform-state-prod"
    REMOTE_STATE_PROJECT="jsj-system-mgmt"
    REMOTE_STATE_LOCATION="US"
    ORG_ID="REDACTED_ORG_ID"
    BILLING_ACCOUNT="REDACTED_BILLING_ACCOUNT"
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
log_info "[1/5] root.hcl 치환 중..."
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
log_info "[2/5] common.naming.tfvars 치환 중..."
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
log_info "[3/5] Jenkinsfile 치환 중..."
JENKINSFILE="${TARGET_DIR}/Jenkinsfile"

sed -i "s|TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/[^']*'|TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/${PROJECT_ID}'|g" "${JENKINSFILE}"

log_success "Jenkinsfile 치환 완료"

# -----------------------------------------------------------------------------
# 4. 10-network/terraform.tfvars - 서브넷 이름
# -----------------------------------------------------------------------------
log_info "[4/5] 10-network/terraform.tfvars 치환 중..."
NETWORK_TFVARS="${TARGET_DIR}/10-network/terraform.tfvars"

# 서브넷 이름 패턴 치환: game-l-subnet-xxx → ${PROJECT_NAME}-subnet-xxx
sed -i "s|\"[^\"]*-subnet-dmz\"|\"${PROJECT_NAME}-subnet-dmz\"|g" "${NETWORK_TFVARS}"
sed -i "s|\"[^\"]*-subnet-private\"|\"${PROJECT_NAME}-subnet-private\"|g" "${NETWORK_TFVARS}"
sed -i "s|\"[^\"]*-subnet-db\"|\"${PROJECT_NAME}-subnet-db\"|g" "${NETWORK_TFVARS}"

log_success "10-network/terraform.tfvars 치환 완료"

# -----------------------------------------------------------------------------
# 5. 50-workloads/terraform.tfvars - subnetwork_self_link
# -----------------------------------------------------------------------------
log_info "[5/5] 50-workloads/terraform.tfvars 치환 중..."
WORKLOADS_TFVARS="${TARGET_DIR}/50-workloads/terraform.tfvars"

# subnetwork_self_link 패턴 치환
# projects/xxx/regions/xxx/subnetworks/xxx → projects/${PROJECT_ID}/regions/${REGION_PRIMARY}/subnetworks/${PROJECT_NAME}-subnet-xxx
sed -i "s|projects/[^/]*/regions/[^/]*/subnetworks/[^\"]*-subnet-dmz|projects/${PROJECT_ID}/regions/${REGION_PRIMARY}/subnetworks/${PROJECT_NAME}-subnet-dmz|g" "${WORKLOADS_TFVARS}"
sed -i "s|projects/[^/]*/regions/[^/]*/subnetworks/[^\"]*-subnet-private|projects/${PROJECT_ID}/regions/${REGION_PRIMARY}/subnetworks/${PROJECT_NAME}-subnet-private|g" "${WORKLOADS_TFVARS}"
sed -i "s|projects/[^/]*/regions/[^/]*/subnetworks/[^\"]*-subnet-db|projects/${PROJECT_ID}/regions/${REGION_PRIMARY}/subnetworks/${PROJECT_NAME}-subnet-db|g" "${WORKLOADS_TFVARS}"

log_success "50-workloads/terraform.tfvars 치환 완료"

# =============================================================================
# Git 작업
# =============================================================================

log_info "Git 브랜치 생성 및 커밋 중..."

BRANCH_NAME="feature/create-project-${PROJECT_ID}"

cd "${REPO_ROOT}"

# 브랜치 생성
git checkout -b "${BRANCH_NAME}"

# 파일 추가
git add "environments/LIVE/${PROJECT_ID}"

# 커밋
git commit -m "feat: ${PROJECT_ID} 프로젝트 생성

- proj-default-templet 기반으로 신규 프로젝트 생성
- PROJECT_ID: ${PROJECT_ID}
- PROJECT_NAME: ${PROJECT_NAME}
- ORGANIZATION: ${ORGANIZATION}
- REGION: ${REGION_PRIMARY}

🤖 Generated with create_project.sh"

log_success "Git 커밋 완료 (브랜치: ${BRANCH_NAME})"

# =============================================================================
# Pull Request 생성 (선택사항)
# =============================================================================

if command -v gh &> /dev/null; then
    log_info "Pull Request 생성 여부를 확인합니다..."
    read -p "PR을 생성하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Pull Request 생성 중..."

        PR_TITLE="[Infra] ${PROJECT_ID} 프로젝트 생성"
        PR_BODY="## 📋 신규 프로젝트 생성

### 프로젝트 정보
- **PROJECT_ID**: \`${PROJECT_ID}\`
- **PROJECT_NAME**: \`${PROJECT_NAME}\`
- **ORGANIZATION**: \`${ORGANIZATION}\`
- **REGION_PRIMARY**: \`${REGION_PRIMARY}\`
- **REGION_BACKUP**: \`${REGION_BACKUP}\`

### 변경 내역
- [x] proj-default-templet 복사
- [x] root.hcl 설정 치환
- [x] common.naming.tfvars 설정 치환
- [x] Jenkinsfile TG_WORKING_DIR 업데이트
- [x] 네트워크 서브넷 이름 업데이트
- [x] Workload subnetwork_self_link 업데이트

### 다음 단계
1. PR 리뷰 및 머지
2. Jenkins Job 생성 (terraform-deploy-${PROJECT_ID})
3. 초기 인프라 배포 (00-project부터 순차적으로)

🤖 자동 생성됨: create_project.sh"

        gh pr create \
            --title "${PR_TITLE}" \
            --body "${PR_BODY}" \
            --base main \
            --head "${BRANCH_NAME}"

        log_success "Pull Request 생성 완료!"
    else
        log_info "PR 생성을 건너뜁니다."
        log_info "수동으로 생성하려면: git push -u origin ${BRANCH_NAME}"
    fi
else
    log_warn "gh CLI가 설치되어 있지 않습니다. PR을 수동으로 생성하세요."
    log_info "브랜치 푸시: git push -u origin ${BRANCH_NAME}"
fi

# =============================================================================
# 완료
# =============================================================================

echo ""
log_success "프로젝트 생성 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  프로젝트 위치: ${TARGET_DIR}"
echo "  Git 브랜치: ${BRANCH_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "다음 단계:"
echo "  1. git push -u origin ${BRANCH_NAME}  # (PR 생성하지 않은 경우)"
echo "  2. PR 리뷰 및 머지"
echo "  3. Jenkins에서 terraform-deploy-${PROJECT_ID} Job 생성"
echo "  4. 초기 배포: 00-project → 10-network → ... 순서로 apply"
echo ""
