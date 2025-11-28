# Project Configuration
# Uncomment and set region to override the default from common.naming.tfvars.
# region = "asia-northeast3"
# Parent settings
folder_id       = null
# billing_account는 루트 terragrunt.hcl(inputs)의 값을 사용합니다.
# 필요 시 아래 라인을 주석 해제 후 올바른 ID로 설정하세요.
# billing_account = "REDACTED_BILLING_ACCOUNT"

# Labels (only add extra labels here; modules/naming.common_labels will be merged)
labels = {
  # team = "dev-team"
}

# APIs to enable
apis = [
  "cloudresourcemanager.googleapis.com",
  "serviceusage.googleapis.com",
  "compute.googleapis.com",
  "iam.googleapis.com",
  "servicenetworking.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "cloudkms.googleapis.com",
  "cloudbuild.googleapis.com",
  "container.googleapis.com",
  "sqladmin.googleapis.com", # Cloud SQL
  "redis.googleapis.com"     # Memorystore Redis
]

# Budget settings
# Note: Budget API requires special quota project configuration
# Disabled by default to avoid authentication issues during deployment
# You can enable it manually via GCP Console: Billing → Budgets & alerts
enable_budget   = false
budget_amount   = 1000
budget_currency = "USD"

# Logging settings
log_retention_days              = 90
# 신규 프로젝트 초기 적용에서 Cloud Logging API 전파 지연으로 실패할 수 있어
# 기본 로그 버킷 관리를 1차 적용에서 비활성화합니다. (추후 true로 바꿔 재적용)
manage_default_logging_bucket   = false
# 전파 시간이 충분할 경우 주석 해제하여 대기시간을 늘릴 수 있습니다. (예: "180s")
# logging_api_wait_duration       = "120s"

# CMEK settings (optional)
# cmek_key_id = "projects/security-project/locations/us-central1/keyRings/main-ring/cryptoKeys/main-key"
