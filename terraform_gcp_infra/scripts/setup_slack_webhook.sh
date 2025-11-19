#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Slack Webhook 설정 스크립트
# =============================================================================
# Slack Incoming Webhook URL을 GCP Secret Manager에 안전하게 저장합니다.
#
# 사용법:
#   setup_slack_webhook.sh <project-id> <slack-webhook-url>
#
# 예시:
#   setup_slack_webhook.sh jsj-system-mgmt https://hooks.slack.com/services/YOUR/WEBHOOK/URL
# =============================================================================

# =============================================================================
# 설정값 (Configuration)
# =============================================================================
# 이 섹션의 값들을 수정하여 환경에 맞게 조정할 수 있습니다.

# Secret Manager 설정
SECRET_NAME="slack-webhook-url"                  # Secret 이름
SECRET_REPLICATION_POLICY="automatic"            # 복제 정책 (automatic/user-managed)
API_NAME="secretmanager.googleapis.com"          # Secret Manager API 이름

# =============================================================================
# 경로 설정
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# 함수 정의
# =============================================================================

# 사용법 출력
usage() {
  cat <<USAGE
사용법:
  setup_slack_webhook.sh <project-id> <slack-webhook-url>

예시:
  setup_slack_webhook.sh jsj-system-mgmt https://hooks.slack.com/services/YOUR/WEBHOOK/URL

설명:
  Slack Incoming Webhook URL을 GCP Secret Manager에 안전하게 저장합니다.
  Secret 이름: ${SECRET_NAME}

사전 준비사항:
  1. Slack Incoming Webhook 생성:
     - Slack Workspace 설정 → Apps → Incoming Webhooks
     - "Add to Slack" 클릭 후 채널 선택
     - Webhook URL 복사

  2. GCP 권한:
     - Secret Manager Admin (roles/secretmanager.admin)

USAGE
}

PROJECT_ID="${1:-}"
WEBHOOK_URL="${2:-}"

if [[ -z "${PROJECT_ID}" || -z "${WEBHOOK_URL}" ]]; then
  usage
  exit 1
fi

# =============================================================================
# 메인 로직
# =============================================================================

# gcloud CLI 확인
if ! command -v gcloud >/dev/null 2>&1; then
  echo "[ERROR] gcloud CLI가 설치되어 있지 않습니다. Google Cloud SDK를 설치하세요." >&2
  exit 1
fi

echo "[INFO] Slack Webhook URL을 Secret Manager에 저장 중..."
echo "[INFO] 프로젝트: ${PROJECT_ID}"
echo "[INFO] Secret 이름: ${SECRET_NAME}"

# Secret Manager API 활성화
echo "[INFO] Secret Manager API 활성화 중..."
gcloud services enable "${API_NAME}" \
  --project="${PROJECT_ID}" 2>/dev/null || true

# Secret이 이미 존재하는지 확인
if gcloud secrets describe "${SECRET_NAME}" \
    --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "[WARN] Secret '${SECRET_NAME}'이(가) 이미 존재합니다."
  read -p "새 버전을 추가하시겠습니까? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "[INFO] 중단되었습니다."
    exit 0
  fi

  # 새 버전 추가
  echo "[INFO] 새 버전 추가 중..."
  echo "${WEBHOOK_URL}" | gcloud secrets versions add "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --data-file=-

  echo "[SUCCESS] Secret '${SECRET_NAME}'에 새 버전이 추가되었습니다."
else
  # Secret 생성
  echo "[INFO] Secret '${SECRET_NAME}' 생성 중..."
  echo "${WEBHOOK_URL}" | gcloud secrets create "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --replication-policy="${SECRET_REPLICATION_POLICY}" \
    --data-file=-

  echo "[SUCCESS] Secret '${SECRET_NAME}'이(가) 성공적으로 생성되었습니다."
fi

# Secret 정보 출력
echo ""
echo "================================"
echo "Secret 상세 정보:"
echo "================================"
gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}"

echo ""
echo "[SUCCESS] 설정 완료!"
echo ""
echo "다음 단계:"
echo "1. Terraform에서 이 Secret을 사용하여 Notification Channel 생성"
echo "2. terraform.tfvars에서 알림 활성화"
echo ""
echo "Secret 리소스 이름:"
echo "  projects/${PROJECT_ID}/secrets/${SECRET_NAME}"
