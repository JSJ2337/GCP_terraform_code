locals {
  # ============================================================================
  # 원격 상태 버킷 설정
  # ============================================================================
  # ⚠️ 템플릿 기본값 - create_project.sh에서 자동 치환됨
  # 수동 수정 시 아래 값들을 직접 변경하거나 환경변수 사용

  # sed 치환용 변수 (create_project.sh에서 치환)
  remote_state_bucket   = "REPLACE_REMOTE_STATE_BUCKET"
  remote_state_project  = "REPLACE_REMOTE_STATE_PROJECT"
  remote_state_location = "REPLACE_REMOTE_STATE_LOCATION"
  project_state_prefix  = "REPLACE_PROJECT_STATE_PREFIX"

  # ============================================================================
  # 플레이스홀더 검증 로직
  # ============================================================================
  # REPLACE_ 접두사가 남아있으면 치환이 안 된 것
  placeholder_patterns = ["REPLACE_", "YOUR_"]

  detected_placeholders = flatten([
    for key, value in {
      "remote_state_bucket"   = local.remote_state_bucket
      "remote_state_project"  = local.remote_state_project
      "remote_state_location" = local.remote_state_location
      "project_state_prefix"  = local.project_state_prefix
    } : [
      for pattern in local.placeholder_patterns :
      "${key}=${value}" if can(regex(pattern, value))
    ]
  ])

  all_violations = local.detected_placeholders

  # inputs 값 (sed 치환용)
  org_id          = "REPLACE_ORG_ID"
  billing_account = "REPLACE_BILLING_ACCOUNT"
}

# Terragrunt 원격 상태 구성: 각 레이어별로 고유 prefix를 자동 부여한다.
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket               = local.remote_state_bucket
    project              = local.remote_state_project
    location             = local.remote_state_location
    prefix               = "${local.project_state_prefix}/${path_relative_to_include()}"
    skip_bucket_creation = true
  }
}

# ============================================================================
# 환경별 공통 입력
# ============================================================================
# ⚠️ 템플릿 플레이스홀더 - create_project.sh에서 자동 치환됨
inputs = {
  org_id          = local.org_id
  billing_account = local.billing_account

  # 관리 프로젝트 ID (Cross-Project PSC 등에 사용)
  management_project_id = local.remote_state_project

  # Bootstrap remote state 설정 (00-project에서 사용)
  bootstrap_state_bucket = local.remote_state_bucket
  bootstrap_state_prefix = "bootstrap/00-foundation"
}

# ============================================================================
# Terragrunt Hook: 실행 전 검증
# ============================================================================
# Terragrunt 실행 전에 플레이스홀더 값이 있는지 검사
terraform {
  before_hook "validate_config" {
    commands     = ["init", "plan", "apply", "destroy", "output", "refresh"]
    execute      = ["bash", "-c", <<-EOF
      set -e

      # 원격 상태 설정 검증
      if [ ${length(local.all_violations)} -gt 0 ]; then
        echo "=========================================================================="
        echo "❌ ERROR: 플레이스홀더 값이 치환되지 않았습니다!"
        echo "=========================================================================="
        echo ""
        echo "발견된 문제:"
        %{for violation in local.all_violations~}
        echo "  - ${violation}"
        %{endfor~}
        echo ""
        echo "해결 방법:"
        echo "  create_project.sh 스크립트로 프로젝트를 생성하세요."
        echo ""
        echo "⚠️  다른 프로젝트의 상태 파일을 오염시킬 수 있으므로 진행할 수 없습니다!"
        echo "=========================================================================="
        exit 1
      fi

      # org_id 검증
      if echo "${local.org_id}" | grep -qE "REPLACE_"; then
        echo "=========================================================================="
        echo "❌ ERROR: org_id가 플레이스홀더 값입니다!"
        echo "=========================================================================="
        echo "발견된 값: ${local.org_id}"
        exit 1
      fi

      # billing_account 검증
      if echo "${local.billing_account}" | grep -qE "REPLACE_"; then
        echo "=========================================================================="
        echo "❌ ERROR: billing_account가 플레이스홀더 값입니다!"
        echo "=========================================================================="
        echo "발견된 값: ${local.billing_account}"
        exit 1
      fi

      echo "✅ 설정 검증 통과: 모든 값이 올바르게 설정되었습니다."
    EOF
    ]
    run_on_error = false
  }
}
