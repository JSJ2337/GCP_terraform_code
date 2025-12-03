# Bootstrap Root Configuration
# 모든 Bootstrap 레이어에서 공통으로 사용하는 설정
#
# 환경 변수:
#   - TG_BOOTSTRAP_STATE_BUCKET: State 버킷 이름 (기본값: delabs-terraform-state-live)
#   - TG_BOOTSTRAP_STATE_PROJECT: State 버킷이 있는 프로젝트 (기본값: delabs-gcp-mgmt)
#   - TG_BOOTSTRAP_STATE_LOCATION: State 버킷 위치 (기본값: ASIA)
#   - TG_USE_LOCAL_BACKEND: 로컬 백엔드 사용 여부 (기본값: false)

locals {
  # 환경 변수에서 state bucket 이름을 가져오거나 기본값 사용
  state_bucket   = get_env("TG_BOOTSTRAP_STATE_BUCKET", "delabs-terraform-state-live")
  state_project  = get_env("TG_BOOTSTRAP_STATE_PROJECT", "delabs-gcp-mgmt")
  state_location = get_env("TG_BOOTSTRAP_STATE_LOCATION", "ASIA")

  # 로컬 백엔드 사용 여부 (초기 부트스트랩 시 true로 설정)
  # 사용법: TG_USE_LOCAL_BACKEND=true terragrunt apply
  use_local_backend = tobool(get_env("TG_USE_LOCAL_BACKEND", "false"))
}

# Remote State 설정 (조건부)
remote_state {
  backend = local.use_local_backend ? "local" : "gcs"

  config = local.use_local_backend ? {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  } : {
    bucket   = local.state_bucket
    prefix   = "bootstrap/${path_relative_to_include()}"
    project  = local.state_project
    location = local.state_location
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Terraform 버전 및 Provider 설정 생성
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30"
    }
  }
}

provider "google" {
  # 인증은 환경변수 또는 gcloud auth application-default login 사용
}

provider "google-beta" {
  # Beta 기능이 필요한 리소스용
}
EOF
}
