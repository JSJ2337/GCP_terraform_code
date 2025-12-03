# 10-network 레이어 설정

locals {
  # Primary Subnet CIDR (asia-northeast3)
  subnet_cidr = "10.250.10.0/24"

  # us-west1 Subnet CIDR (PSC Endpoint용)
  subnet_cidr_us_west1 = "10.250.20.0/24"

  # Jenkins 접근 허용 CIDR (회사 IP로 제한)
  # TODO: 실제 회사 IP로 변경 필요
  jenkins_allowed_cidrs = ["0.0.0.0/0"]

  # PSC Endpoints for Cloud SQL
  psc_endpoints = {
    gcby-cloudsql = {
      region                    = "us-west1"
      ip_address                = "10.250.20.20"
      target_service_attachment = "projects/va89486946f7d978dp-tp/regions/us-west1/serviceAttachments/a-ddb66ab8241d-psc-service-attachment-e4480ecfda9f3356"
      allow_global_access       = true
    }
  }
}
