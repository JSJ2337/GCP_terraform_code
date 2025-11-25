# =============================================================================
# 50-compute Terragrunt Configuration
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

# 00-foundation 의존성
dependency "foundation" {
  config_path = "../00-foundation"

  mock_outputs = {
    management_project_id         = "mock-project-id"
    management_project_number     = "000000000000"
    jenkins_service_account_email = "mock-sa@mock-project.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# 10-network 의존성
dependency "network" {
  config_path = "../10-network"

  mock_outputs = {
    vpc_self_link    = "projects/mock-project/global/networks/mock-vpc"
    subnet_self_link = "projects/mock-project/regions/asia-northeast3/subnetworks/mock-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# 의존성 순서
dependencies {
  paths = ["../00-foundation", "../10-network", "../20-storage"]
}

inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    management_project_id         = dependency.foundation.outputs.management_project_id
    jenkins_service_account_email = dependency.foundation.outputs.jenkins_service_account_email
    vpc_self_link                 = dependency.network.outputs.vpc_self_link
    subnet_self_link              = dependency.network.outputs.subnet_self_link
  }
)
