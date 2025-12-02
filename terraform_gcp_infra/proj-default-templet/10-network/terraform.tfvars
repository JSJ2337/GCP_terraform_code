# Network Configuration
# region은 terragrunt.hcl에서 region_primary 자동 주입
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/Private zones)
# name, region은 terragrunt.hcl에서 project_name, region_primary 기반 자동 생성
# CIDR만 정의 (네트워크 대역 설계)
additional_subnets = [
  {
    cidr = "10.3.0.0/24"  # DMZ subnet
  },
  {
    cidr = "10.3.1.0/24"  # Private subnet
  }
]

# Subnet 이름은 terragrunt.hcl에서 자동 생성
# 형식: {project_name}-subnet-dmz, {project_name}-subnet-private

# Private Service Connection (VPC Peering 방식) - DISABLED
# PSC Endpoint 방식으로 전환하여 더 이상 사용하지 않음
enable_private_service_connection = false
# private_service_connection_address = "10.3.2.0"
# private_service_connection_prefix_length = 24

# Cloud NAT configuration
nat_min_ports_per_vm = 1024

# Firewall rules
firewall_rules = [
  {
    name           = "allow-ssh-from-iap"
    direction      = "INGRESS"
    ranges         = ["35.235.240.0/20"] # IAP range
    allow_protocol = "tcp"
    allow_ports    = ["22"]
    target_tags    = ["ssh-from-iap"]
    description    = "Allow SSH from Identity-Aware Proxy"
  },
  # DMZ zone internal communication
  {
    name           = "allow-dmz-internal"
    direction      = "INGRESS"
    ranges         = ["10.3.0.0/24"] # DMZ subnet only
    allow_protocol = "all"
    allow_ports    = []
    target_tags    = ["dmz-zone"]
    description    = "Allow all traffic within DMZ subnet (10.3.0.0/24)"
  },
  # Private zone internal communication
  {
    name           = "allow-private-internal"
    direction      = "INGRESS"
    ranges         = ["10.3.1.0/24"] # Private subnet only
    allow_protocol = "all"
    allow_ports    = []
    target_tags    = ["private-zone"]
    description    = "Allow all traffic within Private subnet (10.3.1.0/24)"
  },
  # DMZ to Private communication (frontend -> backend)
  {
    name           = "allow-dmz-to-private"
    direction      = "INGRESS"
    ranges         = ["10.3.0.0/24"] # From DMZ
    allow_protocol = "tcp"
    allow_ports    = ["8080", "9090", "3000", "5000"]
    target_tags    = ["private-zone"]
    description    = "Allow DMZ to Private zone (frontend to backend APIs)"
  },
  {
    name           = "allow-health-check"
    direction      = "INGRESS"
    ranges         = ["130.211.0.0/22", "35.191.0.0/16"] # Health check ranges
    allow_protocol = "tcp"
    allow_ports    = ["80", "8080"]
    target_tags    = ["dmz-zone", "private-zone"]
    description    = "Allow health checks from Google Load Balancer"
  }
]

# Memorystore Enterprise용 PSC 자동 구성
enable_memorystore_psc_policy = true
# memorystore_psc_region은 terragrunt.hcl에서 region_primary 자동 주입
# memorystore_psc_subnet_name은 terragrunt.hcl에서 자동 생성 (기본: private subnet)
memorystore_psc_connection_limit = 8

# Cloud SQL용 PSC Endpoint 구성 (Private subnet 전용 접근)
# NOTE: Cloud SQL은 Service Connection Policy를 지원하지 않음
# Cloud SQL은 VPC Peering 방식 또는 PSC Endpoint(다른 방식)를 사용
# Service Connection Policy는 Memorystore 등 일부 서비스만 지원
enable_cloudsql_psc_policy = false
# cloudsql_psc_region은 terragrunt.hcl에서 region_primary 자동 주입
# cloudsql_psc_subnet_name은 terragrunt.hcl에서 자동 생성 (기본: private subnet)
cloudsql_psc_connection_limit = 5  # Master + Read Replicas
