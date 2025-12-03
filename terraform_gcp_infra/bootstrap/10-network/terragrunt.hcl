# =============================================================================
# 10-network Terragrunt Configuration
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  parent_dir = abspath("${get_terragrunt_dir()}/..")

  # 공통 입력 읽기 (HCL 파일 직접 파싱)
  common_vars = read_terragrunt_config("${local.parent_dir}/common.hcl")

  # 레이어 입력 읽기
  layer_vars = read_terragrunt_config("${get_terragrunt_dir()}/layer.hcl")
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
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "gcby_cache" {
  config_path = local.common_vars.locals.projects.gcby.cache_path

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-gcby-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# 새 프로젝트 추가 예시 (주석)
# dependency "abc_database" {
#   config_path = local.common_vars.locals.projects.abc.database_path
#
#   mock_outputs = {
#     psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-cloudsql"
#   }
#   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
# }
#
# dependency "abc_cache" {
#   config_path = local.common_vars.locals.projects.abc.cache_path
#
#   mock_outputs = {
#     psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-redis"
#   }
#   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
# }

dependencies {
  paths = ["../00-foundation"]
}

# =============================================================================
# Inputs: projects 구조에서 동적으로 생성
# =============================================================================
locals {
  # projects map에서 추출
  projects = local.common_vars.locals.projects

  # 각 프로젝트별 VPC Peering 정보 (key = network_url)
  # 새 프로젝트 추가 시: common.hcl의 projects에 추가하면 자동 반영
  project_vpc_peerings = {
    for key, project in local.projects :
    key => project.network_url
  }

  # PSC Endpoints 동적 생성 (각 프로젝트의 Cloud SQL, Redis)
  # 형식: {project_key}-{service} = { psc_ip, service_attachment }
  #
  # 주의: dependency는 정적 선언이 필요하므로,
  # 프로젝트 추가 시 위의 dependency 블록도 함께 추가해야 함
  psc_endpoints_gcby = {
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
  }

  # 새 프로젝트 추가 예시 (주석)
  # psc_endpoints_abc = {
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
  # }

  # 모든 프로젝트의 PSC endpoints 병합
  all_psc_endpoints = merge(
    local.psc_endpoints_gcby,
    # local.psc_endpoints_abc,  # 새 프로젝트 추가 시 주석 해제
  )
}

# common.hcl + layer.hcl + 동적 생성된 PSC endpoints
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    # VPC Peering 대상 목록 (자동 생성)
    project_vpc_network_urls = local.project_vpc_peerings

    # PSC Endpoints (모든 프로젝트 통합)
    psc_endpoints = local.all_psc_endpoints
  }
)
