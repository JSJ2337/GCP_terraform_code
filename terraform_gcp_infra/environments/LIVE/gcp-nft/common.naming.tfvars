# =============================================================================
# 공통 네이밍 입력 (모든 레이어에서 공유)
# =============================================================================
# 주의: organization은 리소스 네이밍 접두어로 사용되므로 소문자/숫자/하이픈 권장
# 도메인이 있다면 슬러그 형태로: 예) mycompany.com → mycompany
# ⚠️ 아래 값들은 create_project.sh에서 자동 치환됨

project_id     = "gcp-nft"
project_name   = "nft"
environment    = "live"
organization   = "delabs"
region_primary = "asia-northeast3"
region_backup  = "asia-northeast1"

# Bootstrap 폴더 설정 (environment_folder_ids 키 조회용)
# 형식: product/region/env → "my-project/asia-northeast3/LIVE"
folder_product = "gcp-nft"
folder_region  = "asia-northeast3"
folder_env     = "LIVE"

# =============================================================================
# 선택 입력 (필요 시 주석 해제해 사용)
# =============================================================================
# default_zone_suffix = "a"   # naming.default_zone 계산 시 접미사

base_labels = {
  managed-by  = "terraform"
  project     = "nft"
  team        = "delabs-team"
}

# extra_tags = ["prod", "game"]  # 공통 태그

# =============================================================================
# 네트워크 설계 (중앙 관리)
# =============================================================================
network_config = {
  # Subnet CIDR - 프로젝트별로 중복되지 않게 설계
  subnets = {
    dmz     = "10.X.X.0/24"   # 예: 10.10.10.0/24
    private = "10.X.X.0/24"   # 예: 10.10.11.0/24
    psc     = "10.X.X.0/24"   # 예: 10.10.12.0/24
  }

  # PSC Endpoint IP
  # Redis Cluster PSC는 자동 생성되므로 실제 IP 사용
  psc_endpoints = {
    cloudsql = "10.X.X.51"
    redis    = ["10.X.X.3", "10.X.X.2"]
  }

  # VPC Peering
  peering = {
    mgmt_project_id  = "jsj-system-mgmt"
    mgmt_vpc_name    = "YOUR_MGMT_VPC_NAME"
    mgmt_subnet_cidr = "10.250.10.0/24"  # mgmt VPC subnet CIDR (firewall rule용)
  }
}

# =============================================================================
# VM Static IP (최상위 레벨 - terragrunt에서 쉽게 접근하기 위함)
# =============================================================================
vm_static_ips = {
  # 예시: game01 = "10.10.11.3"
}

# =============================================================================
# 관리 프로젝트 정보
# =============================================================================
management_project_id = "jsj-system-mgmt"

# =============================================================================
# DNS 설정
# =============================================================================
dns_config = {
  domain      = "YOUR_DOMAIN.internal."  # Private DNS 도메인 (trailing dot 필수)
  zone_suffix = "YOUR_ZONE_SUFFIX"       # Zone 이름 접미사
}

# =============================================================================
# VM Admin 사용자 설정 (startup script에서 사용)
# =============================================================================
# 보안 주의: 비밀번호는 초기 배포 후 반드시 변경 필요!
# 참고: 비밀번호에 ! 문자는 bash history expansion 충돌로 SSH 접속 시 문제 발생
vm_admin_config = {
  username = "YOUR_ADMIN_USERNAME"
  password = "YOUR_ADMIN_PASSWORD"
}
