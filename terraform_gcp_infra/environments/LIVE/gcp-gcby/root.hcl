locals {
  # 모든 레이어에서 공유하는 원격 상태 버킷과 prefix 기본값
  remote_state_bucket   = "delabs-terraform-state-live"
  remote_state_project  = "delabs-gcp-mgmt"
  remote_state_location = "ASIA"
  project_state_prefix  = "gcp-gcby"
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
  org_id          = "1034166519592"  # GCP Organization ID (delabsgames.gg)
  billing_account = "01B77E-0A986D-CB2651"

  # 관리 프로젝트 ID (Cross-Project PSC 등에 사용)
  management_project_id = "delabs-gcp-mgmt"

  # Bootstrap remote state 설정 (00-project에서 사용)
  # bootstrap이 레이어 구조로 되어 있어서 00-foundation을 참조
  bootstrap_state_bucket = local.remote_state_bucket
  bootstrap_state_prefix = "bootstrap/00-foundation"
}
