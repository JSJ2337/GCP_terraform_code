locals {
  # 모든 레이어에서 공유하는 원격 상태 버킷과 prefix 기본값
  remote_state_bucket   = "jsj-terraform-state-prod"
  remote_state_project  = "jsj-system-mgmt"
  remote_state_location = "US"
  project_state_prefix  = "jsj-game-k"
}

# Terragrunt 원격 상태 구성: 각 레이어별로 고유 prefix를 자동 부여한다.
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket                = local.remote_state_bucket
    project               = local.remote_state_project
    location              = local.remote_state_location
    prefix                = "${local.project_state_prefix}/${path_relative_to_include()}"
    skip_bucket_creation  = true
  }
}

# 환경별 공통 입력
inputs = {
  org_id          = "REDACTED_ORG_ID"  # jsj-dev.com
  billing_account = "REDACTED_BILLING_ACCOUNT"
}
