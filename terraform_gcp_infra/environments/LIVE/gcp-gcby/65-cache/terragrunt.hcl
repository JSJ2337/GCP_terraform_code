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

  # common.naming.tfvars에서 프로젝트 정보 추출
  project_name = local.common_inputs.project_name
  environment  = local.common_inputs.environment

  # Management 프로젝트 정보 (common.naming.tfvars에서 가져옴)
  mgmt_project_id = local.common_inputs.management_project_id
  state_bucket    = get_env("TG_STATE_BUCKET")  # 환경변수 필수

  # 기존 labels에 app 추가
  merged_labels = merge(
    try(local.layer_inputs.labels, {}),
    { app = local.project_name }
  )
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # Management 프로젝트 정보 동적 주입
    mgmt_project_id  = local.mgmt_project_id
    mgmt_vpc_network = "projects/${local.mgmt_project_id}/global/networks/${local.mgmt_project_id}-vpc"
    state_bucket     = local.state_bucket

    # display_name 동적 생성
    display_name = "${local.project_name}-${local.environment}-redis"

    # labels에 app 추가
    labels = local.merged_labels
  }
)

dependencies {
  paths = [
    "../00-project",
    "../10-network"
  ]
}
