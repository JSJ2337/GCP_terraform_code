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

  # Network config 추출
  network_config = try(local.common_inputs.network_config, {})

  # Subnet 이름 자동 생성
  subnet_types = ["dmz", "private", "psc"]

  # additional_subnets를 network_config에서 동적 생성
  # CIDR은 common.naming.tfvars의 network_config.subnets에서 가져옴
  # 기존 인프라와 일치하도록 {project_name}-live-subnet-{type} 형태 유지
  additional_subnets_with_metadata = [
    for idx, subnet_type in local.subnet_types :
    {
      name   = "${local.project_name}-live-subnet-${subnet_type}"
      region = local.region_primary
      cidr   = try(local.network_config.subnets[subnet_type], "")
      private_google_access = true
      secondary_ranges      = []
    }
  ]

  # Subnet 이름들 (기존 인프라와 일치)
  dmz_subnet_name     = "${local.project_name}-live-subnet-dmz"
  private_subnet_name = "${local.project_name}-live-subnet-private"
  psc_subnet_name     = "${local.project_name}-live-subnet-psc"

  # Memorystore PSC 설정 - PSC subnet (10.10.12.x)을 사용해야 함
  memorystore_psc_region      = local.region_primary
  memorystore_psc_subnet_name = local.psc_subnet_name  # PSC 서브넷 사용 (private 아님!)

  # VPC Peering 대상
  mgmt_project_id = try(local.network_config.peering.mgmt_project_id, "delabs-gcp-mgmt")
  mgmt_vpc_name   = try(local.network_config.peering.mgmt_vpc_name, "delabs-gcp-mgmt-vpc")
  peer_network_url = "projects/${local.mgmt_project_id}/global/networks/${local.mgmt_vpc_name}"

  # PSC Endpoint IPs
  psc_cloudsql_ip = try(local.network_config.psc_endpoints.cloudsql, "10.10.12.51")
  psc_redis_ips   = try(local.network_config.psc_endpoints.redis, ["10.10.12.101", "10.10.12.102"])
}

# Cloud SQL dependency (Service Attachment 가져오기)
dependency "database" {
  config_path = "../60-database"

  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Redis dependency (Service Attachments 가져오기 - Discovery + Shard)
dependency "cache" {
  config_path = "../65-cache"

  mock_outputs = {
    psc_service_attachment_links = [
      "projects/mock/regions/us-west1/serviceAttachments/mock-redis-discovery",
      "projects/mock/regions/us-west1/serviceAttachments/mock-redis-shard"
    ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # additional_subnets를 명시적으로 override (terragrunt에서 처리한 버전 사용)
    additional_subnets          = local.additional_subnets_with_metadata
    dmz_subnet_name             = local.dmz_subnet_name
    private_subnet_name         = local.private_subnet_name
    db_subnet_name              = local.psc_subnet_name
    memorystore_psc_region      = local.memorystore_psc_region
    memorystore_psc_subnet_name = local.memorystore_psc_subnet_name

    # VPC Peering (common.naming.tfvars에서 가져옴)
    peer_network_url = local.peer_network_url

    # PSC Endpoint IPs (common.naming.tfvars에서 가져옴)
    psc_cloudsql_ip = local.psc_cloudsql_ip
    psc_redis_ips   = local.psc_redis_ips

    # Service Attachment를 dependency에서 가져옴
    cloudsql_service_attachment = dependency.database.outputs.psc_service_attachment_link
    redis_service_attachments   = dependency.cache.outputs.psc_service_attachment_links
  }
)

dependencies {
  paths = ["../00-project"]
}
