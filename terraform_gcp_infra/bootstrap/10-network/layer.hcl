# 10-network 레이어 설정

locals {
  # ==========================================================================
  # Subnet 정의 (for_each 동적 생성)
  # 새 리전 추가 시 여기에만 추가하면 자동으로 Subnet, Router, NAT 생성
  # ==========================================================================
  subnets = {
    primary = {
      region     = "asia-northeast3"
      cidr       = "10.250.10.0/24"
      is_primary = true  # Primary subnet 여부 (naming 구분용)
    }
    us-west1 = {
      region     = "us-west1"
      cidr       = "10.250.20.0/24"
      is_primary = false
    }
    # 새 리전 추가 예시:
    # eu-west1 = {
    #   region     = "europe-west1"
    #   cidr       = "10.250.30.0/24"
    #   is_primary = false
    # }
  }

  # Primary 리전 (기본 리전)
  region_primary = "asia-northeast3"

  # Jenkins 접근 허용 CIDR (회사 IP로 제한)
  # TODO: 실제 회사 IP로 변경 필요
  jenkins_allowed_cidrs = ["0.0.0.0/0"]

  # PSC subnet IP ranges (참고용 - 실제 IP는 common.hcl의 projects에서 관리)
  # Cloud SQL: 10.250.20.51, Redis: 10.250.20.101, 10.250.20.102
  psc_cloudsql_ip = "10.250.20.51"
  psc_redis_ip    = "10.250.20.101"
}
