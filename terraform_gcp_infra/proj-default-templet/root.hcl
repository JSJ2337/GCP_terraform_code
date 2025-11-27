locals {
  # ============================================================================
  # 원격 상태 버킷 설정
  # ============================================================================
  # ⚠️ 템플릿 기본값 - 반드시 실제 값으로 변경 필요!
  # 방법 1: 이 파일에서 직접 수정
  # 방법 2: 환경변수 사용 (export TG_REMOTE_STATE_BUCKET=your-bucket)

  template_defaults = {
    bucket   = "my-terraform-state-prod"
    project  = "my-system-mgmt"
    prefix   = "my-project-prod"
  }

  # 환경변수 우선, 없으면 기본값 사용
  remote_state_bucket   = get_env("TG_REMOTE_STATE_BUCKET", local.template_defaults.bucket)
  remote_state_project  = get_env("TG_REMOTE_STATE_PROJECT", local.template_defaults.project)
  remote_state_location = get_env("TG_REMOTE_STATE_LOCATION", "US")
  project_state_prefix  = get_env("TG_PROJECT_STATE_PREFIX", local.template_defaults.prefix)

  # ============================================================================
  # 플레이스홀더 검증 로직
  # ============================================================================
  # 템플릿 기본값이나 플레이스홀더 패턴을 감지
  placeholder_patterns = ["REPLACE_ME", "YOUR_", "my-.*-prod", "my-system-mgmt"]

  detected_placeholders = flatten([
    for key, value in {
      "remote_state_bucket"  = local.remote_state_bucket
      "remote_state_project" = local.remote_state_project
      "project_state_prefix" = local.project_state_prefix
    } : [
      for pattern in local.placeholder_patterns :
      "${key}=${value}" if can(regex(pattern, value))
    ]
  ])

  # 템플릿 기본값과 정확히 일치하는 경우 감지 (수정된 로직)
  exact_template_matches = flatten([
    for config_key, config_value in {
      "remote_state_bucket"  = local.remote_state_bucket
      "remote_state_project" = local.remote_state_project
      "project_state_prefix" = local.project_state_prefix
    } : [
      "${config_key}=${config_value}"
      if contains([
        local.template_defaults.bucket,
        local.template_defaults.project,
        local.template_defaults.prefix
      ], config_value)
    ]
  ])

  all_violations = distinct(concat(local.detected_placeholders, local.exact_template_matches))

  # inputs 값을 locals에 저장 (hook에서 사용)
  resolved_org_id          = get_env("TG_ORG_ID", "YOUR_ORG_ID")
  resolved_billing_account = get_env("TG_BILLING_ACCOUNT", "YOUR_BILLING_ACCOUNT_ID")
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
# ⚠️ 템플릿 플레이스홀더 - 반드시 실제 값으로 변경 필요!
inputs = {
  org_id          = local.resolved_org_id
  billing_account = local.resolved_billing_account

  # Bootstrap remote state 설정 (00-project에서 사용)
  # bootstrap이 레이어 구조로 되어 있어서 00-foundation을 참조
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
        echo "❌ ERROR: Terraform 원격 상태가 템플릿 기본값을 사용 중입니다!"
        echo "=========================================================================="
        echo ""
        echo "발견된 문제:"
        %{for violation in local.all_violations~}
        echo "  - ${violation}"
        %{endfor~}
        echo ""
        echo "해결 방법:"
        echo "1. terraform_gcp_infra/proj-default-templet/root.hcl을 실제 값으로 수정"
        echo "2. 또는 환경변수 설정:"
        echo "   export TG_REMOTE_STATE_BUCKET=your-actual-bucket"
        echo "   export TG_REMOTE_STATE_PROJECT=your-actual-project"
        echo "   export TG_PROJECT_STATE_PREFIX=your-project-prefix"
        echo ""
        echo "⚠️  다른 프로젝트의 상태 파일을 오염시킬 수 있으므로 진행할 수 없습니다!"
        echo "=========================================================================="
        exit 1
      fi

      # inputs 검증 (resolved 값 사용)
      if echo "${local.resolved_org_id}" | grep -qE "YOUR_|REPLACE_"; then
        echo "=========================================================================="
        echo "❌ ERROR: org_id가 플레이스홀더 값입니다!"
        echo "=========================================================================="
        echo ""
        echo "발견된 값: ${local.resolved_org_id}"
        echo ""
        echo "해결 방법:"
        echo "1. terraform_gcp_infra/proj-default-templet/root.hcl의 locals에서 수정"
        echo "2. 또는: export TG_ORG_ID=your-actual-org-id"
        echo ""
        exit 1
      fi

      if echo "${local.resolved_billing_account}" | grep -qE "YOUR_|REPLACE_"; then
        echo "=========================================================================="
        echo "❌ ERROR: billing_account가 플레이스홀더 값입니다!"
        echo "=========================================================================="
        echo ""
        echo "발견된 값: ${local.resolved_billing_account}"
        echo ""
        echo "해결 방법:"
        echo "1. terraform_gcp_infra/proj-default-templet/root.hcl의 locals에서 수정"
        echo "2. 또는: export TG_BILLING_ACCOUNT=your-actual-billing-account-id"
        echo ""
        exit 1
      fi

      echo "✅ 설정 검증 통과: 모든 값이 올바르게 설정되었습니다."
    EOF
    ]
    run_on_error = false
  }
}
