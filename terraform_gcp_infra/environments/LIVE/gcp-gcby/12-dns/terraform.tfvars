# Private DNS Zone 설정
# zone_name, dns_name, description, private_networks, dns_records는
# terragrunt.hcl에서 common.naming.tfvars 값으로 동적 생성됨
# 아래 변수들은 terragrunt inputs로 주입되므로 여기서 정의하지 않음

# DNS Zone 가시성 (private)
visibility = "private"

# DNSSEC 설정
enable_dnssec = false

# DNS Forwarding 설정 (사용하지 않음)
target_name_servers = []

# DNS Peering 설정 (사용하지 않음 - 전용 zone으로 변경)
peering_network = ""

# DNS 레코드 목록
# terragrunt.hcl에서 common.naming.tfvars 값으로 동적 생성됨
# (project_name, environment, network_config.psc_endpoints, vm_ips 사용)

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
