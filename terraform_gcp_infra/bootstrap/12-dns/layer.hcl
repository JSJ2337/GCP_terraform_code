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

    # Cloud SQL PSC endpoint (mgmt VPC용)
    "gcby-live-gdb-m1" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.20.20"]
    }

    # Redis PSC endpoint (mgmt VPC용)
    "gcby-live-redis" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.20.101"]
    }

    # 새 서버 추가 시 여기에 추가
    # "gitlab" = {
    #   type    = "A"
    #   ttl     = 300
    #   rrdatas = ["10.250.10.5"]
    # }
  }
}
