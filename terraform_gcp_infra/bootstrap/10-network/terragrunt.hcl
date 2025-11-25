# =============================================================================
# 10-network Terragrunt Configuration
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  parent_dir = abspath("${get_terragrunt_dir()}/..")

  # 공통 입력 읽기
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.bootstrap.tfvars")

  # 레이어 입력 읽기
  raw_layer_inputs = read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars")
}

# 00-foundation 의존성
dependency "foundation" {
  config_path = "../00-foundation"

  mock_outputs = {
    management_project_id     = "mock-project-id"
    management_project_number = "000000000000"
    jenkins_service_account_email = "mock-sa@mock-project.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependencies {
  paths = ["../00-foundation"]
}

inputs = merge(
  local.raw_common_inputs,
  local.raw_layer_inputs,
  {
    management_project_id = dependency.foundation.outputs.management_project_id
  }
)
