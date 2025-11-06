include "root" {
  path = find_in_parent_folders()
}

# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  override_file_path = "${local.parent_dir}/common.override.tfvars"
  raw_override_inputs = try(read_tfvars_file(local.override_file_path), {})
  override_inputs     = local.raw_override_inputs is map ? local.raw_override_inputs : try(jsondecode(local.raw_override_inputs), {})

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)
}

inputs = merge(
  local.common_inputs,
  local.override_inputs,
  local.layer_inputs
)
