# Network Configuration
# region은 terragrunt.hcl에서 region_primary 자동 주입
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/WAS/DB zones)
# name, region은 terragrunt.hcl에서 project_name, region_primary 기반 자동 생성
# CIDR만 정의 (네트워크 대역 설계)
additional_subnets = [
  {
    cidr = "10.3.0.0/24"  # DMZ subnet
  },
  {
    cidr = "10.3.1.0/24"  # Private subnet
  },
  {
    cidr = "10.3.2.0/24"  # DB subnet
  }
]

# Subnet 이름은 terragrunt.hcl에서 자동 생성
# 형식: {project_name}-subnet-dmz, {project_name}-subnet-private, {project_name}-subnet-db

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
    target_tags    = ["ssh-allowed"]
    description    = "Allow SSH from Identity-Aware Proxy"
  },
  {
    name           = "allow-game-traffic"
    direction      = "INGRESS"
    ranges         = ["10.1.0.0/16", "10.2.0.0/16"]
    allow_protocol = "tcp"
    allow_ports    = ["8080", "9090"]
    target_tags    = ["game", "app"]
    description    = "Allow game traffic between subnets"
  },
  {
    name           = "allow-health-check"
    direction      = "INGRESS"
    ranges         = ["130.211.0.0/22", "35.191.0.0/16"] # Health check ranges
    allow_protocol = "tcp"
    allow_ports    = ["8080"]
    target_tags    = ["game", "app"]
    description    = "Allow health checks from Google Load Balancer"
  }
]

# Memorystore Enterprise용 PSC 자동 구성
enable_memorystore_psc_policy = true
# memorystore_psc_region은 terragrunt.hcl에서 region_primary 자동 주입
# memorystore_psc_subnet_name은 terragrunt.hcl에서 자동 생성
memorystore_psc_connection_limit = 8
