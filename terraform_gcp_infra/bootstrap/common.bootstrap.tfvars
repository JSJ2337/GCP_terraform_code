# Bootstrap 공통 설정
# 모든 레이어에서 공유하는 값들

# GCP 조직 정보
organization_id = "REDACTED_ORG_ID"
billing_account = "REDACTED_BILLING_ACCOUNT"

# 관리 프로젝트 정보
management_project_id   = "jsj-system-mgmt"
management_project_name = "jsj-system-mgmt"

# 공통 레이블
labels = {
  managed_by  = "terraform"
  purpose     = "bootstrap"
  team        = "platform"
  cost_center = "infrastructure"
}

# 리전 설정
region_primary = "asia-northeast3"
region_backup  = "us-central1"
