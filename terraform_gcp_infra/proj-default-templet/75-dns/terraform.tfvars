# DNS Managed Zone 설정
# zone_name은 비워두면 자동으로 "{project_name}-{environment}-zone" 형식으로 생성됩니다
zone_name   = ""
dns_name    = "example.com."
description = "Example DNS zone"

# DNS Zone 가시성 (public 또는 private)
# - public: 인터넷에 공개되는 DNS Zone
# - private: VPC 내부에서만 사용하는 DNS Zone
visibility = "public"

# Private DNS Zone 설정 (visibility = "private"일 때만 사용)
# VPC 네트워크 self-link 목록 (비우면 naming 모듈의 VPC 사용)
private_networks = []

# DNSSEC 설정 (Public Zone에서만 사용 가능)
enable_dnssec = false

# DNS Forwarding 설정 (Private Zone에서 외부 DNS로 쿼리 전달)
# 예: 온프레미스 DNS 서버로 전달
target_name_servers = []
# target_name_servers = [
#   {
#     ipv4_address    = "192.168.1.10"
#     forwarding_path = "default"
#   }
# ]

# DNS Peering 설정 (다른 VPC의 DNS Zone과 연결)
peering_network = ""

# Reverse Lookup (PTR records) 활성화
reverse_lookup = false

# DNS 레코드 목록
dns_records = [
  # A 레코드
  {
    name    = "example.com."
    type    = "A"
    ttl     = 300
    rrdatas = ["203.0.113.1"]
  },
  # CNAME 레코드
  {
    name    = "www.example.com."
    type    = "CNAME"
    ttl     = 300
    rrdatas = ["example.com."]
  }
]

# DNS Policy 설정 (고급 설정, 필요 시 활성화)
create_dns_policy = false
dns_policy_name   = ""
dns_policy_description = ""

# Inbound DNS Forwarding (외부에서 VPC DNS로 쿼리 가능)
enable_inbound_forwarding = false

# DNS 쿼리 로깅
enable_dns_logging = false

# 대체 네임서버 (Google DNS 대신 사용)
alternative_name_servers = []

# DNS Policy가 적용될 VPC 네트워크 목록
dns_policy_networks = []

# 추가 라벨
labels = {
  tier = "dns"
  app  = "default-templet"
}
