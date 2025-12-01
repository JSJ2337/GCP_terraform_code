# DNS Peering Zone 설정 (mgmt VPC의 DNS Zone과 연결)
# zone_name은 비워두면 자동으로 "{project_name}-{environment}-zone" 형식으로 생성됩니다
zone_name   = "gcby-dns-peering-to-mgmt"
dns_name    = "delabsgames.internal."
description = "DNS Peering to mgmt VPC for internal name resolution"

# DNS Zone 가시성 (private)
# mgmt VPC의 DNS Zone과 peering하므로 private
visibility = "private"

# Private DNS Zone 설정
# gcby VPC에서 사용 (비우면 naming 모듈의 VPC 사용)
private_networks = []

# DNSSEC 설정 (Peering Zone에서는 사용 불가)
enable_dnssec = false

# DNS Forwarding 설정 (사용하지 않음)
target_name_servers = []

# DNS Peering 설정 (mgmt VPC의 DNS Zone과 연결)
# mgmt VPC의 delabs-gcp-mgmt-vpc를 peering 대상으로 설정
peering_network = "projects/delabs-gcp-mgmt/global/networks/delabs-gcp-mgmt-vpc"

# DNS 레코드 목록
# Peering Zone이므로 레코드는 mgmt의 bootstrap/12-dns에서 관리
dns_records = []

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
