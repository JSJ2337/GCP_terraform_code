# =============================================================================
# 15-firewall Terragrunt Configuration
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
    vpc_name      = "mock-vpc"
    vpc_self_link = "projects/mock/global/networks/mock-vpc"
    subnet_cidr   = "10.0.0.0/24"
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
    vpc_name      = dependency.network.outputs.vpc_name
    vpc_self_link = dependency.network.outputs.vpc_self_link
    subnet_cidr   = dependency.network.outputs.subnet_cidr
  }
)
