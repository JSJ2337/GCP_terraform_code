# Management Project Configuration
project_id      = "jsj-system-mgmt"
project_name    = "jsj-system-mgmt"
billing_account = "REDACTED_BILLING_ACCOUNT"
folder_id       = null # No folder

# Labels
labels = {
  managed_by  = "terraform"
  purpose     = "state-management"
  team        = "platform"
  cost_center = "infrastructure"
}

# Terraform State Buckets
bucket_name_prod = "jsj-terraform-state-prod"
bucket_name_dev  = "jsj-terraform-state-dev" # 선택사항
bucket_location  = "US"

# Dev 버킷 생성 여부 (필요하면 true로 변경)
create_dev_bucket = false

# GCP 조직 ID (Service Account 권한 부여 시 필요)
# 조직 ID: REDACTED_ORG_ID (jsj-dev.com)
organization_id = "REDACTED_ORG_ID"

# Bootstrap 옵션 플래그
manage_folders = true
manage_org_iam = false
enable_billing_account_binding = false
