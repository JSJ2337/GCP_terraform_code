# 10-network 레이어 설정

locals {
  # Subnet CIDR
  subnet_cidr = "10.250.10.0/24"

  # Jenkins 접근 허용 CIDR (회사 IP로 제한)
  # TODO: 실제 회사 IP로 변경 필요
  jenkins_allowed_cidrs = ["0.0.0.0/0"]
}
