# =============================================================================
# 12-dns Terragrunt Configuration
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

# 10-network 의존성 (VPC 정보 필요)
dependency "network" {
  config_path = "../10-network"

  mock_outputs = {
    vpc_self_link = "projects/mock/global/networks/mock-vpc"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependencies {
  paths = ["../00-foundation", "../10-network"]
}

# common.hcl + layer.hcl + network dependency 출력 병합
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    vpc_self_link = dependency.network.outputs.vpc_self_link

    # projects map에서 프로젝트의 network_url 추출하여 DNS Zone에 추가
    # 단, 자체 DNS Zone이 있는 프로젝트(gcby 등)는 제외 (같은 DNS 이름 충돌 방지)
    additional_networks = [
      for key, project in local.common_vars.locals.projects : project.network_url
      if try(project.has_own_dns_zone, false) == false
    ]
  }
)
