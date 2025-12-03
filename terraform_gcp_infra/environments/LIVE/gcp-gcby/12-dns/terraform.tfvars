# Private DNS Zone 설정
# zone_name, dns_name, description은 terragrunt.hcl에서 common.naming.tfvars 값으로 동적 생성됨
zone_name   = ""
dns_name    = ""
description = ""

# DNS Zone 가시성 (private)
visibility = "private"

# Private DNS Zone 설정
# gcby VPC에서 사용 (terragrunt.hcl에서 10-network dependency로 주입)
private_networks = []

# DNSSEC 설정
enable_dnssec = false

# DNS Forwarding 설정 (사용하지 않음)
target_name_servers = []

# DNS Peering 설정 (사용하지 않음 - 전용 zone으로 변경)
peering_network = ""

# DNS 레코드 목록
# terragrunt.hcl에서 common.naming.tfvars 값으로 동적 생성됨
# (project_name, environment, network_config.psc_endpoints, vm_ips 사용)
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

# 추가 라벨 (app은 terragrunt.hcl에서 project_name으로 override됨)
labels = {
  tier     = "dns"
  dns_type = "private"
}
