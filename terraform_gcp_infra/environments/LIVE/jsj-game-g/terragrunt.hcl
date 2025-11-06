locals {
  # 모든 레이어에서 공유하는 원격 상태 버킷과 prefix 기본값
  remote_state_bucket   = "delabs-terraform-state-prod"
  remote_state_project  = "delabs-system-mgmt"
  remote_state_location = "US"
  project_state_prefix  = "jsj-game-g"
}

# Terragrunt 원격 상태 구성: 각 레이어별로 고유 prefix를 자동 부여한다.
remote_state {
  backend = "gcs"
  config = {
    bucket   = local.remote_state_bucket
    prefix   = "${local.project_state_prefix}/${path_relative_to_include()}"
    project  = local.remote_state_project
    location = local.remote_state_location
  }
}
