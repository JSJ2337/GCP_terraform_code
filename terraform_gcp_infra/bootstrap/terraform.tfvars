# Management Project Configuration
project_id      = "delabs-system-mgmt"
project_name    = "delabs-system-mgmt"
billing_account = "01076D-327AD5-FC8922"
folder_id       = null # No folder

# Labels
labels = {
  managed_by  = "terraform"
  purpose     = "state-management"
  team        = "platform"
  cost_center = "infrastructure"
}

# Terraform State Buckets
bucket_name_prod = "delabs-terraform-state-prod"
bucket_name_dev  = "delabs-terraform-state-dev" # 선택사항
bucket_location  = "US"

# Dev 버킷 생성 여부 (필요하면 true로 변경)
create_dev_bucket = false

# GCP 조직 ID (Service Account 권한 부여 시 필요)
# 조직 ID 확인: gcloud organizations list
organization_id = ""  # 예: "123456789012"
