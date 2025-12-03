# =============================================================================
# 10-network Terragrunt Configuration
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# =============================================================================
# Locals: 기본 변수만 정의 (dependency 참조 불가)
# =============================================================================
locals {
  parent_dir = abspath("${get_terragrunt_dir()}/..")

  # 공통 입력 읽기 (HCL 파일 직접 파싱)
  common_vars = read_terragrunt_config("${local.parent_dir}/common.hcl")

  # 레이어 입력 읽기
  layer_vars = read_terragrunt_config("${get_terragrunt_dir()}/layer.hcl")

  # projects map에서 추출
  projects = local.common_vars.locals.projects

  # 각 프로젝트별 VPC Peering 정보 (key = network_url)
  # 새 프로젝트 추가 시: common.hcl의 projects에 추가하면 자동 반영
  project_vpc_peerings = {
    for key, project in local.projects :
    key => project.network_url
  }
}

# 00-foundation 의존성 (실행 순서 보장용)
dependency "foundation" {
  config_path = "../00-foundation"

  # local backend 사용 시에도 동작하도록 skip_outputs 설정
  skip_outputs = true
}

# =============================================================================
# 프로젝트별 Database/Cache Dependencies
# =============================================================================
# 새 프로젝트 추가 시: common.hcl의 projects에 추가 후 여기에 dependency 블록 추가
#
# gcby 프로젝트 dependencies
dependency "gcby_database" {
  config_path = local.common_vars.locals.projects.gcby.database_path

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-gcby-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "gcby_cache" {
  config_path = local.common_vars.locals.projects.gcby.cache_path

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-gcby-redis"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# 새 프로젝트 추가 예시 (주석)
# dependency "abc_database" {
#   config_path = local.common_vars.locals.projects.abc.database_path
#
#   mock_outputs = {
#     psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-cloudsql"
#   }
#   mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
#   mock_outputs_merge_strategy_with_state  = "shallow"
# }
#
# dependency "abc_cache" {
#   config_path = local.common_vars.locals.projects.abc.cache_path
#
#   mock_outputs = {
#     psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-redis"
#   }
#   mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
#   mock_outputs_merge_strategy_with_state  = "shallow"
# }

dependencies {
  paths = ["../00-foundation"]
}

# =============================================================================
# Inputs: common.hcl + layer.hcl + PSC Endpoints (dependency 참조)
# =============================================================================
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    # VPC Peering 대상 목록 (자동 생성)
    project_vpc_network_urls = local.project_vpc_peerings

    # PSC Endpoints (dependency 참조는 inputs에서만 가능)
    # 새 프로젝트 추가 시: dependency 블록 추가 후 여기에도 추가
    psc_endpoints = merge(
      # gcby 프로젝트
      {
        "gcby-cloudsql" = {
          region                    = "us-west1"
          ip_address                = local.projects.gcby.psc_ips.cloudsql
          target_service_attachment = dependency.gcby_database.outputs.psc_service_attachment_link
          allow_global_access       = true
        }
        "gcby-redis" = {
          region                    = "us-west1"
          ip_address                = local.projects.gcby.psc_ips.redis
          target_service_attachment = dependency.gcby_cache.outputs.psc_service_attachment_link
          allow_global_access       = true
        }
      },
      # 새 프로젝트 추가 예시 (주석)
      # {
      #   "abc-cloudsql" = {
      #     region                    = "us-west1"
      #     ip_address                = local.projects.abc.psc_ips.cloudsql
      #     target_service_attachment = dependency.abc_database.outputs.psc_service_attachment_link
      #     allow_global_access       = true
      #   }
      #   "abc-redis" = {
      #     region                    = "us-west1"
      #     ip_address                = local.projects.abc.psc_ips.redis
      #     target_service_attachment = dependency.abc_cache.outputs.psc_service_attachment_link
      #     allow_global_access       = true
      #   }
      # },
    )
  }
)
