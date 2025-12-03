include "root" {
  path = find_in_parent_folders("root.hcl")
}

# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

dependencies {
  paths = [
    "../00-project",
    "../10-network"  # Private DNS Zone의 경우 VPC 네트워크 필요
  ]
}

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  # common.naming.tfvars에서 프로젝트 정보 추출 (mock_outputs용)
  project_id   = local.common_inputs.project_id
  project_name = local.common_inputs.project_name
  environment  = local.common_inputs.environment

  # VPC 이름 동적 생성: {project_name}-{environment}-vpc
  vpc_name           = "${local.project_name}-${local.environment}-vpc"
  vpc_self_link_mock = "projects/${local.project_id}/global/networks/${local.vpc_name}"

  # Network config 추출
  network_config = try(local.common_inputs.network_config, {})

  # DNS 레코드 동적 생성 (common.naming.tfvars의 network_config에서 IP 가져옴)
  dns_records = [
    {
      name    = "${local.project_name}-${local.environment}-gdb-m1"
      type    = "A"
      ttl     = 300
      rrdatas = [try(local.network_config.psc_endpoints.cloudsql, "10.10.12.51")]
    },
    {
      name    = "${local.project_name}-${local.environment}-redis"
      type    = "A"
      ttl     = 300
      rrdatas = [try(local.network_config.psc_endpoints.redis[0], "10.10.12.101")]
    },
    {
      name    = "${local.project_name}-gs01"
      type    = "A"
      ttl     = 300
      rrdatas = [try(local.network_config.vm_ips.gs01, "10.10.11.3")]
    },
    {
      name    = "${local.project_name}-gs02"
      type    = "A"
      ttl     = 300
      rrdatas = [try(local.network_config.vm_ips.gs02, "10.10.11.6")]
    }
  ]
}

# 10-network에서 VPC self_link 가져오기
dependency "network" {
  config_path = "../10-network"

  mock_outputs = {
    vpc_self_link = local.vpc_self_link_mock
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # DNS 레코드를 동적 생성한 것으로 override
    dns_records = local.dns_records

    # Private DNS Zone이 연결될 VPC (10-network에서 동적으로 가져옴)
    private_networks = [dependency.network.outputs.vpc_self_link]
  }
)
