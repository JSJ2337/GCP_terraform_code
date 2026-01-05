# Management Project Configuration
project_id      = "jsj-system-mgmt"
project_name    = "jsj-system-mgmt"
billing_account = ""  # 환경변수 TF_VAR_billing_account 또는 별도 파일로 관리
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

# GCP 조직 ID (환경변수 TF_VAR_organization_id 또는 별도 파일로 관리)
organization_id = ""

# Bootstrap 옵션 플래그
manage_folders = true
manage_org_iam = false
enable_billing_account_binding = false
