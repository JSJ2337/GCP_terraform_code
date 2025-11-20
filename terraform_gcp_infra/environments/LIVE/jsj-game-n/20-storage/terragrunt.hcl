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

  default_assets_cors_rules = [
    {
      origin          = [
        "https://${local.common_inputs.project_name}.example.com",
        "https://cdn.${local.common_inputs.project_name}.example.com"
      ]
      method          = ["GET", "HEAD"]
      response_header = ["Content-Type", "Cache-Control"]
      max_age_seconds = 3600
    }
  ]

  layer_inputs_without_cors = { for k, v in local.layer_inputs : k => v if k != "assets_cors_rules" }
  assets_cors_rules_effective = try(local.layer_inputs.assets_cors_rules, null)
  assets_cors_rules_final = (
    local.assets_cors_rules_effective == null || length(local.assets_cors_rules_effective) == 0
  ) ? local.default_assets_cors_rules : local.assets_cors_rules_effective
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs_without_cors,
  {
    assets_cors_rules = local.assets_cors_rules_final
  }
)

dependencies {
  paths = ["../00-project"]
}
