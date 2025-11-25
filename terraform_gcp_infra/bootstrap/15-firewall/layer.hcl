# 15-firewall 레이어 설정

locals {
  # 방화벽 관련 설정
  jenkins_allowed_cidrs = ["0.0.0.0/0"]  # 운영 시 제한 필요
  bastion_allowed_cidrs = ["0.0.0.0/0"]  # 운영 시 제한 필요
}
