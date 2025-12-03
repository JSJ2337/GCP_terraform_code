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

# gcby Cloud SQL dependency (Service Attachment 가져오기)
dependency "gcby_database" {
  config_path = "../../environments/LIVE/gcp-gcby/60-database"

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# gcby Redis dependency (Service Attachment 가져오기)
dependency "gcby_cache" {
  config_path = "../../environments/LIVE/gcp-gcby/65-cache"

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependencies {
  paths = ["../00-foundation"]
}

# common.hcl에서 직접 값을 가져옴 (dependency output 대신)
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    # VPC Peering 대상 (common.hcl에서 가져옴)
    gcby_vpc_network_url = local.common_vars.locals.gcby_vpc_network_url

    # Service Attachment를 dependency에서 가져옴
    gcby_cloudsql_service_attachment = dependency.gcby_database.outputs.psc_service_attachment_link
    gcby_redis_service_attachment    = dependency.gcby_cache.outputs.psc_service_attachment_link
  }
)
