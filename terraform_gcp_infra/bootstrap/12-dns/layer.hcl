# 12-dns 레이어 설정

locals {
  # DNS Zone 설정
  dns_zone_name = "delabsgames-internal"
  dns_domain    = "delabsgames.internal."

  # VM 내부 IP 주소 (50-compute에서 생성된 VM들)
  # 10-network layer.hcl의 subnet_cidr: 10.250.10.0/24 기준
  jenkins_internal_ip = "10.250.10.4"
  bastion_internal_ip = "10.250.10.3"

  # 추가 DNS 레코드 (필요시 추가)
  # 형식: hostname = { type = "A", ttl = 300, rrdatas = ["IP"] }
  additional_dns_records = {
    # 예시:
    # "gitlab" = {
    #   type    = "A"
    #   ttl     = 300
    #   rrdatas = ["10.250.10.5"]
    # }
  }
}
