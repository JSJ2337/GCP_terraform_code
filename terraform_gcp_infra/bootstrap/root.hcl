# Bootstrap Root Configuration
# 모든 Bootstrap 레이어에서 공통으로 사용하는 설정

locals {
  # 환경 변수에서 state bucket 이름을 가져오거나 기본값 사용
  state_bucket = get_env("TG_BOOTSTRAP_STATE_BUCKET", "jsj-terraform-state-prod")
}

# Remote State 설정
remote_state {
  backend = "gcs"

  config = {
    bucket   = local.state_bucket
    prefix   = "bootstrap/${path_relative_to_include()}"
    project  = "jsj-system-mgmt"
    location = "US"
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
