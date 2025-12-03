# 10-network 레이어 설정

locals {
  # Primary Subnet CIDR (asia-northeast3)
  subnet_cidr = "10.250.10.0/24"

  # Secondary Subnet CIDR (us-west1, PSC Endpoint용)
  subnet_cidr_secondary = "10.250.20.0/24"

  # Jenkins 접근 허용 CIDR (회사 IP로 제한)
  # TODO: 실제 회사 IP로 변경 필요
  jenkins_allowed_cidrs = ["0.0.0.0/0"]

  # PSC subnet IP ranges
  psc_cloudsql_ip = "10.250.20.20"
  psc_redis_ip    = "10.250.20.101"
}
