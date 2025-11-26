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

  # 프로젝트명과 리전 추출
  project_name   = local.common_inputs.project_name
  region_primary = local.common_inputs.region_primary

  # Subnet 이름 자동 생성
  subnet_types = ["dmz", "private", "db"]

  # additional_subnets에 name과 region 자동 추가
  additional_subnets_with_metadata = [
    for idx, subnet in try(local.layer_inputs.additional_subnets, []) :
    merge(subnet, {
      name   = "${local.project_name}-subnet-${local.subnet_types[idx]}"
      region = local.region_primary
    })
  ]

  # Subnet 이름들
  dmz_subnet_name     = "${local.project_name}-subnet-dmz"
  private_subnet_name = "${local.project_name}-subnet-private"
  db_subnet_name      = "${local.project_name}-subnet-db"

  # Memorystore PSC 설정
  memorystore_psc_region      = local.region_primary
  memorystore_psc_subnet_name = local.private_subnet_name
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # additional_subnets를 명시적으로 override (terragrunt에서 처리한 버전 사용)
    additional_subnets          = local.additional_subnets_with_metadata
    dmz_subnet_name             = local.dmz_subnet_name
    private_subnet_name         = local.private_subnet_name
    db_subnet_name              = local.db_subnet_name
    memorystore_psc_region      = local.memorystore_psc_region
    memorystore_psc_subnet_name = local.memorystore_psc_subnet_name
  }
)

dependencies {
  paths = ["../00-project"]
}
