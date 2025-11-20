include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  # Read Replicas에 자동으로 region 주입
  read_replicas_with_region = {
    for k, v in try(local.layer_inputs.read_replicas, {}) :
    k => merge(v, {
      region = try(v.region, local.common_inputs.region_primary)
    })
  }
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    read_replicas = local.read_replicas_with_region
  }
)

dependencies {
  paths = [
    "../00-project",
    "../10-network"
  ]
}
