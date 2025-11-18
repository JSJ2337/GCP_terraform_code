include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

dependencies {
  paths = [
    "../../00-project",
    "../../10-network"
  ]
}

dependency "workloads" {
  config_path = "../../50-workloads"

  mock_outputs = {
    instance_groups = {}
  }

  # destroy 실행 시에만 mock outputs 사용하도록 설정
  mock_outputs_allowed_terraform_commands = ["destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/../..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  # destroy 명령어인지 확인
  is_destroy = get_terraform_command() == "destroy"
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  # destroy가 아닐 때만 auto_instance_groups 추가
  local.is_destroy ? {} : {
    auto_instance_groups = {
      for name, link in try(dependency.workloads.outputs.instance_groups, {}) :
      name => link
      if length(regexall("web", lower(name))) > 0
    }
  }
)
