include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 60-database, 65-cache 배포 후 실행
dependencies {
  paths = [
    "../00-project",
    "../10-network",
    "../60-database",
    "../65-cache"
  ]
}

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  # 프로젝트 정보
  project_id     = local.common_inputs.project_id
  project_name   = local.common_inputs.project_name
  environment    = local.common_inputs.environment
  region_primary = local.common_inputs.region_primary

  # Network config
  network_config = try(local.common_inputs.network_config, {})

  # VPC/Subnet 이름
  vpc_name        = "${local.project_name}-${local.environment}-vpc"
  psc_subnet_name = "${local.project_name}-${local.environment}-subnet-psc"

  # PSC IP 주소 (common.naming.tfvars에서)
  psc_cloudsql_ip = local.network_config.psc_endpoints.cloudsql
  psc_redis_ips   = local.network_config.psc_endpoints.redis

  # Management 프로젝트 정보
  mgmt_project_id = local.common_inputs.management_project_id
  state_bucket    = get_env("TG_STATE_BUCKET", "YOUR_STATE_BUCKET")
}

# 60-database에서 service_attachment 가져오기
dependency "database" {
  config_path = "../60-database"

  mock_outputs = {
    psc_service_attachment_link = ""
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# 65-cache에서 service_attachments 및 cross-project PSC 설정 가져오기
dependency "cache" {
  config_path = "../65-cache"

  mock_outputs = {
    instance_name                = ""
    psc_service_attachment_links = []
    enable_cross_project_psc     = false
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

inputs = merge(
  local.common_inputs,
  {
    # Network 정보
    vpc_name        = local.vpc_name
    psc_subnet_name = local.psc_subnet_name

    # PSC IP 주소
    psc_cloudsql_ip = local.psc_cloudsql_ip
    psc_redis_ips   = local.psc_redis_ips

    # Service Attachments (dependency에서 가져옴)
    cloudsql_service_attachment = dependency.database.outputs.psc_service_attachment_link
    redis_service_attachments   = dependency.cache.outputs.psc_service_attachment_links

    # Cross-project PSC 설정 (65-cache의 terraform.tfvars에서 가져옴)
    enable_cross_project_psc = dependency.cache.outputs.enable_cross_project_psc
    state_bucket             = local.state_bucket
    redis_cluster_name       = dependency.cache.outputs.instance_name
    mgmt_project_id          = local.mgmt_project_id
    mgmt_vpc_network         = "projects/${local.mgmt_project_id}/global/networks/${local.mgmt_project_id}-vpc"
  }
)
