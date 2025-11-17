#!/usr/bin/env bash
set -euo pipefail

# Slack Webhook URL을 GCP Secret Manager에 저장하는 헬퍼 스크립트

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  setup_slack_webhook.sh <project-id> <slack-webhook-url>

Example:
  setup_slack_webhook.sh jsj-system-mgmt https://hooks.slack.com/services/YOUR/WEBHOOK/URL

Description:
  Slack Incoming Webhook URL을 GCP Secret Manager에 안전하게 저장합니다.
  Secret 이름: slack-webhook-url

Prerequisites:
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

if ! command -v gcloud >/dev/null 2>&1; then
  echo "[ERROR] gcloud CLI not found. Please install Google Cloud SDK." >&2
  exit 1
fi

echo "[INFO] Setting up Slack Webhook URL in Secret Manager..."
echo "[INFO] Project: ${PROJECT_ID}"

# Secret Manager API 활성화 확인
echo "[INFO] Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com \
  --project="${PROJECT_ID}" 2>/dev/null || true

# Secret 이름
SECRET_NAME="slack-webhook-url"

# Secret이 이미 존재하는지 확인
if gcloud secrets describe "${SECRET_NAME}" \
    --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "[WARN] Secret '${SECRET_NAME}' already exists."
  read -p "Do you want to add a new version? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "[INFO] Aborted."
    exit 0
  fi

  # 새 버전 추가
  echo "${WEBHOOK_URL}" | gcloud secrets versions add "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --data-file=-

  echo "[SUCCESS] New version added to secret '${SECRET_NAME}'."
else
  # Secret 생성
  echo "[INFO] Creating secret '${SECRET_NAME}'..."
  echo "${WEBHOOK_URL}" | gcloud secrets create "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --replication-policy="automatic" \
    --data-file=-

  echo "[SUCCESS] Secret '${SECRET_NAME}' created successfully."
fi

# Secret 정보 출력
echo ""
echo "================================"
echo "Secret Details:"
echo "================================"
gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}"

echo ""
echo "[SUCCESS] Setup complete!"
echo ""
echo "Next steps:"
echo "1. Terraform에서 이 Secret을 사용하여 Notification Channel 생성"
echo "2. terraform.tfvars에서 알림 활성화"
echo ""
echo "Secret resource name:"
echo "  projects/${PROJECT_ID}/secrets/${SECRET_NAME}"
