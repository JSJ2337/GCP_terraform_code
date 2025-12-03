# 공통 네이밍 입력 (모든 레이어에서 공유)
# 주의: organization은 리소스 네이밍 접두어로 사용되므로 소문자/숫자/하이픈 권장
# 도메인이 있다면 슬러그 형태로: 예) mycompany.com → mycompany
project_id     = "gcp-gcby"
project_name   = "gcby"
environment    = "live"
organization   = "delabs"  # 조직명 또는 도메인 슬러그
region_primary = "us-west1"         # Oregon (오레곤)
region_backup  = "us-west2"         # Los Angeles (백업/DR)

# Bootstrap 폴더 설정 (environment_folder_ids 키 조회용)
# 형식: product/region/env → "gcp-gcby/us-west1/LIVE"
folder_product = "gcp-gcby"
folder_region  = "us-west1"
folder_env     = "LIVE"

# 선택 입력 (필요 시 주석 해제해 사용)
# default_zone_suffix = "a"   # naming.default_zone 계산 시 접미사
base_labels = {              # naming.common_labels에 병합되는 기본 라벨
  managed-by  = "terraform"
  project     = "gcby"
  team        = "system-team"
}
# extra_tags = ["prod", "gcby"]  # 공통 태그

# 네트워크 설계 (중앙 관리)
network_config = {
  # Subnet CIDR
  subnets = {
    dmz     = "10.10.10.0/24"
    private = "10.10.11.0/24"
    psc     = "10.10.12.0/24"
  }

  # PSC Endpoint IP
  # Redis Cluster는 2개의 Service Attachment (Discovery + Shard)가 있으므로 2개 IP 필요
  psc_endpoints = {
    cloudsql = "10.10.12.51"
    redis    = ["10.10.12.101", "10.10.12.102"]
  }

  # VPC Peering
  peering = {
    mgmt_project_id  = "delabs-gcp-mgmt"
    mgmt_vpc_name    = "delabs-gcp-mgmt-vpc"
    mgmt_subnet_cidr = "10.250.10.0/24"  # mgmt VPC subnet CIDR (firewall rule용)
  }

  # VM Static IP (선택사항, 비우면 동적 할당)
  vm_ips = {
    gs01 = "10.10.11.3"
    gs02 = "10.10.11.6"
  }
}

# 관리 프로젝트 정보
management_project_id = "delabs-gcp-mgmt"

# DNS 설정
dns_config = {
  domain      = "delabsgames.internal."  # Private DNS 도메인 (trailing dot 필수)
  zone_suffix = "delabsgames-internal"   # Zone 이름 접미사
}

# VM Admin 사용자 설정 (startup script에서 사용)
# 보안 주의: 비밀번호는 초기 배포 후 반드시 변경 필요!
vm_admin_config = {
  username = "delabs-adm"
  password = "REDACTED_PASSWORD"
}
