# =============================================================================
# 00-foundation Terragrunt Configuration
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

# 의존성 없음 (최상위 레이어)

inputs = merge(
  local.raw_common_inputs,
  local.raw_layer_inputs
)
