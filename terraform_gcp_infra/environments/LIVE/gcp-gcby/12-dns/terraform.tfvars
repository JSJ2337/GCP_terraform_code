# Private DNS Zone 설정 (gcby VPC 전용)
# zone_name은 비워두면 자동으로 "{project_name}-{environment}-zone" 형식으로 생성됩니다
zone_name   = "gcby-delabsgames-internal"
dns_name    = "delabsgames.internal."
description = "Private DNS zone for gcby VPC (delabsgames.internal.)"

# DNS Zone 가시성 (private)
visibility = "private"

# Private DNS Zone 설정
# gcby VPC에서 사용
private_networks = ["projects/gcp-gcby/global/networks/gcby-live-vpc"]

# DNSSEC 설정
enable_dnssec = false

# DNS Forwarding 설정 (사용하지 않음)
target_name_servers = []

# DNS Peering 설정 (사용하지 않음 - 전용 zone으로 변경)
peering_network = ""

# DNS 레코드 목록 (gcby VPC용)
dns_records = [
  {
    name    = "gcby-live-gdb-m1"
    type    = "A"
    ttl     = 300
    rrdatas = ["10.10.12.51"]  # gcby VPC의 Cloud SQL PSC FR IP
  },
  {
    name    = "gcby-live-redis"
    type    = "A"
    ttl     = 300
    rrdatas = ["10.10.11.5"]  # gcby VPC의 Redis PSC endpoint IP
  },
  {
    name    = "gcby-gs01"
    type    = "A"
    ttl     = 300
    rrdatas = ["10.10.11.3"]
  },
  {
    name    = "gcby-gs02"
    type    = "A"
    ttl     = 300
    rrdatas = ["10.10.11.6"]
  }
]

# DNS Policy 설정 (사용하지 않음)
create_dns_policy = false
dns_policy_name   = ""
dns_policy_description = ""

# Inbound DNS Forwarding (사용하지 않음)
enable_inbound_forwarding = false

# DNS 쿼리 로깅
enable_dns_logging = false

# 대체 네임서버 (사용하지 않음)
alternative_name_servers = []

# DNS Policy가 적용될 VPC 네트워크 목록
dns_policy_networks = []

# 추가 라벨
labels = {
  tier = "dns"
  app  = "gcby"
  dns_type = "peering"
}
