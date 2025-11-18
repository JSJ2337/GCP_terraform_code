include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load Balancer Layer 모듈 참조
terraform {
  source = "../../../../../modules/load-balancer-layer"
}

dependencies {
  paths = [
    "../../00-project",
    "../../10-network",
    "../../50-workloads"
  ]
}

dependency "workloads" {
  config_path = "../../50-workloads"

  mock_outputs = {
    instance_groups = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
}

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/../..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # Workloads에서 "lobby"가 포함된 Instance Group만 자동으로 Backend로 추가
    auto_instance_groups = {
      for name, link in try(dependency.workloads.outputs.instance_groups, {}) :
      name => link
      if length(regexall("lobby", lower(name))) > 0
    }
  }
)
