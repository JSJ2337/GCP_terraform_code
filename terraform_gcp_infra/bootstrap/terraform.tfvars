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
