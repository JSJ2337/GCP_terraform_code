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

  # SKIP_WORKLOADS_DEPENDENCY=true 환경변수 설정 시 outputs 건너뛰기
  skip_outputs = get_env("SKIP_WORKLOADS_DEPENDENCY", "false") == "true"

  mock_outputs = {
    vm_details = {}
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
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
    # 50-workloads에서 VM 정보 가져오기
    vm_details = try(dependency.workloads.outputs.vm_details, {})
  }
)
