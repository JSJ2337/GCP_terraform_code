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

  # 프로젝트명, 환경, 리전 추출
  project_name   = local.common_inputs.project_name
  environment    = local.common_inputs.environment  # "live", "stg", "dev" 등
  region_primary = local.common_inputs.region_primary

  # Network config 추출
  network_config = try(local.common_inputs.network_config, {})

  # Subnet 이름 자동 생성
  subnet_types = ["dmz", "private", "psc"]

  # additional_subnets를 network_config에서 동적 생성
  # CIDR은 common.naming.tfvars의 network_config.subnets에서 가져옴
  # 서브넷 이름 형식: {project_name}-{environment}-subnet-{type}
  additional_subnets_with_metadata = [
    for idx, subnet_type in local.subnet_types :
    {
      name   = "${local.project_name}-${local.environment}-subnet-${subnet_type}"
      region = local.region_primary
      cidr   = try(local.network_config.subnets[subnet_type], "")
      private_google_access = true
      secondary_ranges      = []
    }
  ]

  # Subnet 이름들 (environment 변수 사용)
  dmz_subnet_name     = "${local.project_name}-${local.environment}-subnet-dmz"
  private_subnet_name = "${local.project_name}-${local.environment}-subnet-private"
  psc_subnet_name     = "${local.project_name}-${local.environment}-subnet-psc"

  # Memorystore PSC 설정 - PSC subnet (10.10.12.x)을 사용해야 함
  memorystore_psc_region      = local.region_primary
  memorystore_psc_subnet_name = local.psc_subnet_name  # PSC 서브넷 사용 (private 아님!)

  # VPC Peering 대상 (common.naming.tfvars의 network_config.peering 또는 management_project_id에서 가져옴)
  mgmt_project_id = try(
    local.network_config.peering.mgmt_project_id,
    local.common_inputs.management_project_id
  )
  mgmt_vpc_name = try(
    local.network_config.peering.mgmt_vpc_name,
    "${local.mgmt_project_id}-vpc"
  )
  peer_network_url = "projects/${local.mgmt_project_id}/global/networks/${local.mgmt_vpc_name}"

  # PSC Endpoint IPs (common.naming.tfvars의 network_config.psc_endpoints에서 가져옴 - 필수)
  psc_cloudsql_ip = local.network_config.psc_endpoints.cloudsql
  psc_redis_ips   = local.network_config.psc_endpoints.redis

  # Mgmt VPC subnet CIDR (firewall rule용)
  mgmt_subnet_cidr = try(local.network_config.peering.mgmt_subnet_cidr, "")

  # Subnet CIDRs
  dmz_cidr     = local.network_config.subnets.dmz
  private_cidr = local.network_config.subnets.private

  # Firewall rules 동적 생성
  firewall_rules = [
    {
      name           = "allow-ssh-from-iap"
      direction      = "INGRESS"
      ranges         = ["35.235.240.0/20"]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      target_tags    = ["ssh-from-iap"]
      description    = "Allow SSH from Identity-Aware Proxy"
    },
    {
      name           = "allow-ssh-from-mgmt"
      direction      = "INGRESS"
      ranges         = [local.mgmt_subnet_cidr]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      target_tags    = ["ssh-from-mgmt"]
      description    = "Allow SSH from mgmt VPC (jenkins, bastion)"
    },
    {
      name           = "allow-dmz-internal"
      direction      = "INGRESS"
      ranges         = [local.dmz_cidr]
      allow_protocol = "all"
      allow_ports    = []
      target_tags    = ["dmz-zone"]
      description    = "Allow all traffic within DMZ subnet (${local.dmz_cidr})"
    },
    {
      name           = "allow-private-internal"
      direction      = "INGRESS"
      ranges         = [local.private_cidr]
      allow_protocol = "all"
      allow_ports    = []
      target_tags    = ["private-zone"]
      description    = "Allow all traffic within Private subnet (${local.private_cidr})"
    },
    {
      name           = "allow-dmz-to-private"
      direction      = "INGRESS"
      ranges         = [local.dmz_cidr]
      allow_protocol = "tcp"
      allow_ports    = ["8080", "9090", "3000", "5000"]
      target_tags    = ["private-zone"]
      description    = "Allow DMZ to Private zone (frontend to backend APIs)"
    },
    {
      name           = "allow-health-check"
      direction      = "INGRESS"
      ranges         = ["130.211.0.0/22", "35.191.0.0/16"]
      allow_protocol = "tcp"
      allow_ports    = ["80", "8080"]
      target_tags    = ["dmz-zone", "private-zone"]
      description    = "Allow health checks from Google Load Balancer"
    },
    {
      name           = "allow-icmp-from-mgmt"
      direction      = "INGRESS"
      ranges         = [local.mgmt_subnet_cidr]
      allow_protocol = "icmp"
      allow_ports    = []
      target_tags    = ["dmz-zone", "private-zone"]
      description    = "Allow ICMP (ping) from mgmt VPC for monitoring"
    },
    {
      name           = "allow-redis-from-mgmt"
      direction      = "INGRESS"
      ranges         = [local.mgmt_subnet_cidr]
      allow_protocol = "tcp"
      allow_ports    = ["6379"]
      target_tags    = []
      description    = "Allow Redis access from mgmt VPC (bastion) to PSC subnet"
    }
  ]

  # ==========================================================================
  # PSC Service Attachment
  # HashiCorp 권장: 조건부 리소스 생성 (count = var != "" ? 1 : 0)
  # 초기 배포: 빈 값 → PSC endpoint 생성 건너뜀
  # 60-database/65-cache 배포 후: 실제 service attachment 값으로 업데이트
  # ==========================================================================
}

# dependency 블록 제거 - cycle 문제 해결
# PSC endpoint는 placeholder 값으로 생성 후, DB/Cache 배포 완료 시 실제 값으로 업데이트

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

    # Service Attachment - 초기 배포 시 빈 값 (PSC endpoint 생성 건너뜀)
    # DB/Cache 배포 후 실제 service attachment 값으로 업데이트 필요
    cloudsql_service_attachment = ""   # 빈 값 → count = 0 → 리소스 생성 안 함
    redis_service_attachments   = []   # 빈 배열 → count = 0 → 리소스 생성 안 함

    # Firewall rules 동적 주입
    firewall_rules = local.firewall_rules
  }
)

dependencies {
  paths = ["../00-project"]
}
