# 12-dns 레이어 설정

locals {
  # DNS Zone 설정
  dns_zone_name = "delabsgames-internal"
  dns_domain    = "delabsgames.internal."

  # 모든 DNS 레코드를 여기서 관리
  # 형식: hostname = { type = "A", ttl = 300, rrdatas = ["IP"] }
  dns_records = {
    # mgmt 프로젝트 VM들
    "jenkins" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.10.7"]
    }
    "bastion" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.10.6"]
    }

    # gcp-gcby 프로젝트 VM들 (VPC Peering 필요)
    "gcby-gs01" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.10.11.3"]
    }
    "gcby-gs02" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.10.11.6"]
    }

    # 새 서버 추가 시 여기에 추가
    # "gitlab" = {
    #   type    = "A"
    #   ttl     = 300
    #   rrdatas = ["10.250.10.5"]
    # }
  }

  # Private Service Connect Endpoints
  # mgmt VPC에서 다른 프로젝트의 Cloud SQL/Redis 등에 접근하기 위한 PSC 엔드포인트
  psc_endpoints = {
    # gcp-gcby 프로젝트 Cloud SQL 접근용
    "gcby-cloudsql" = {
      name               = "gcby-cloudsql-psc"
      region             = "us-west1"
      subnetwork         = "projects/delabs-gcp-mgmt/regions/us-west1/subnetworks/delabs-gcp-mgmt-subnet"
      service_attachment = "projects/va89486946f7d978dp-tp/regions/us-west1/serviceAttachments/a-be04a6986d44-psc-service-attachment-a54302c8eccd8399"
      dns_name           = "gcby-gdb-m1"
      ip_address         = "10.250.10.20"  # mgmt subnet 내 IP 할당
    }

    # 향후 다른 프로젝트 추가 시 여기에 추가
  }
}
