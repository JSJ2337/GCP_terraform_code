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

  # VM Static IPs 추출 (common.naming.tfvars에서)
  vm_static_ips = try(local.common_inputs.vm_static_ips, {})

  # DNS config 추출 (common.naming.tfvars에서)
  dns_config = try(local.common_inputs.dns_config, {})

  # DNS Zone 동적 생성
  zone_name   = "${local.project_name}-${local.dns_config.zone_suffix}"
  dns_name    = local.dns_config.domain
  description = "Private DNS zone for ${local.project_name} VPC (${trimsuffix(local.dns_config.domain, ".")})"

  # DNS 레코드 동적 생성 (common.naming.tfvars의 network_config에서 IP 가져옴 - 필수)
  dns_records = [
    {
      name    = "${local.project_name}-${local.environment}-gdb-m1"
      type    = "A"
      ttl     = 300
      rrdatas = [local.network_config.psc_endpoints.cloudsql]
    },
    {
      name    = "${local.project_name}-${local.environment}-redis"
      type    = "A"
      ttl     = 300
      rrdatas = [local.network_config.psc_endpoints.redis[0]]
    },
    {
      name    = "${local.project_name}-www01"
      type    = "A"
      ttl     = 300
      rrdatas = [local.vm_static_ips.www01]
    },
    {
      name    = "${local.project_name}-www02"
      type    = "A"
      ttl     = 300
      rrdatas = [local.vm_static_ips.www02]
    },
    {
      name    = "${local.project_name}-www03"
      type    = "A"
      ttl     = 300
      rrdatas = [local.vm_static_ips.www03]
    },
    {
      name    = "${local.project_name}-mint01"
      type    = "A"
      ttl     = 300
      rrdatas = [local.vm_static_ips.mint01]
    },
    {
      name    = "${local.project_name}-mint02"
      type    = "A"
      ttl     = 300
      rrdatas = [local.vm_static_ips.mint02]
    }
  ]

  # 기존 labels에 app 추가
  merged_labels = merge(
    try(local.layer_inputs.labels, {}),
    { app = local.project_name }
  )
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
    # DNS Zone 설정 동적 주입
    zone_name   = local.zone_name
    dns_name    = local.dns_name
    description = local.description

    # DNS 레코드를 동적 생성한 것으로 override
    dns_records = local.dns_records

    # Private DNS Zone이 연결될 VPC (10-network에서 동적으로 가져옴)
    private_networks = [dependency.network.outputs.vpc_self_link]

    # labels에 app 추가
    labels = local.merged_labels
  }
)
