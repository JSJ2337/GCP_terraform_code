# =============================================================================
# 환경변수 설정 (선택사항 - 기본값은 common.naming.tfvars에서 가져옴)
# =============================================================================
# TG_STATE_BUCKET: State 버킷 이름
# TG_STATE_PROJECT: State 버킷이 있는 프로젝트
# TG_STATE_LOCATION: State 버킷 위치
# TG_ORG_ID: GCP Organization ID
# TG_BILLING_ACCOUNT: Billing Account ID
# =============================================================================

locals {
  # common.naming.tfvars에서 설정 읽기
  # root.hcl이 있는 디렉토리를 찾아서 common.naming.tfvars 경로 생성
  root_dir          = dirname(find_in_parent_folders("root.hcl"))
  raw_common_inputs = read_tfvars_file("${local.root_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  # 모든 레이어에서 공유하는 원격 상태 버킷과 prefix 기본값
  # 환경변수 > common.naming.tfvars 순으로 우선순위
  # ⚠️ 아래 기본값은 create_project.sh에서 자동 치환됨
  remote_state_bucket   = get_env("TG_STATE_BUCKET", "jsj-terraform-state-prod")
  remote_state_project  = get_env("TG_STATE_PROJECT", try(local.common_inputs.management_project_id, "jsj-system-mgmt"))
  remote_state_location = get_env("TG_STATE_LOCATION", "US")
  project_state_prefix  = local.common_inputs.project_id
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
  # GCP Organization/Billing 설정 (환경변수 또는 기본값)
  # ⚠️ 아래 기본값은 create_project.sh에서 자동 치환됨
  org_id          = get_env("TG_ORG_ID", "REDACTED_ORG_ID")
  billing_account = get_env("TG_BILLING_ACCOUNT", "REDACTED_BILLING_ACCOUNT")

  # 관리 프로젝트 ID (common.naming.tfvars에서 가져옴)
  management_project_id = try(local.common_inputs.management_project_id, "")

  # Bootstrap remote state 설정 (00-project에서 사용)
  # bootstrap이 레이어 구조로 되어 있어서 00-foundation을 참조
  bootstrap_state_bucket = local.remote_state_bucket
  bootstrap_state_prefix = "bootstrap/00-foundation"
}
