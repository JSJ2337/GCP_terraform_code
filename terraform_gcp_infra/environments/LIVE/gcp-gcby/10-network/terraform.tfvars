# Network Configuration
# region은 terragrunt.hcl에서 region_primary 자동 주입
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/WAS/DB zones)
# name, region은 terragrunt.hcl에서 project_name, region_primary 기반 자동 생성
# CIDR만 정의 (네트워크 대역 설계)
additional_subnets = [
  {
    cidr = "10.10.10.0/24"  # DMZ subnet
  },
  {
    cidr = "10.10.11.0/24"  # Private subnet
  },
  {
    cidr = "10.10.12.0/24"  # DB subnet
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
    name           = "allow-ssh-from-mgmt"
    direction      = "INGRESS"
    ranges         = ["10.250.10.0/24"] # mgmt VPC subnet
    allow_protocol = "tcp"
    allow_ports    = ["22"]
    target_tags    = ["ssh-allowed"]
    description    = "Allow SSH from mgmt VPC (jenkins, bastion)"
  },
  # DMZ zone internal communication
  {
    name           = "allow-dmz-internal"
    direction      = "INGRESS"
    ranges         = ["10.10.10.0/24"] # DMZ subnet only
    allow_protocol = "all"
    allow_ports    = []
    target_tags    = ["dmz-zone"]
    description    = "Allow all traffic within DMZ subnet (10.10.10.0/24)"
  },
  # Private zone internal communication
  {
    name           = "allow-private-internal"
    direction      = "INGRESS"
    ranges         = ["10.10.11.0/24"] # Private subnet only
    allow_protocol = "all"
    allow_ports    = []
    target_tags    = ["private-zone"]
    description    = "Allow all traffic within Private subnet (10.10.11.0/24)"
  },
  # DB zone internal communication
  {
    name           = "allow-db-internal"
    direction      = "INGRESS"
    ranges         = ["10.10.12.0/24"] # DB subnet only
    allow_protocol = "all"
    allow_ports    = []
    target_tags    = ["db-zone"]
    description    = "Allow all traffic within DB subnet (10.10.12.0/24)"
  },
  # DMZ to Private communication (frontend -> backend)
  {
    name           = "allow-dmz-to-private"
    direction      = "INGRESS"
    ranges         = ["10.10.10.0/24"] # From DMZ
    allow_protocol = "tcp"
    allow_ports    = ["8080", "9090", "3000", "5000"]
    target_tags    = ["private-zone"]
    description    = "Allow DMZ to Private zone (frontend to backend APIs)"
  },
  # Private to DB communication (backend -> database)
  {
    name           = "allow-private-to-db"
    direction      = "INGRESS"
    ranges         = ["10.10.11.0/24"] # From Private
    allow_protocol = "tcp"
    allow_ports    = ["3306", "5432", "6379", "27017"]
    target_tags    = ["db-zone"]
    description    = "Allow Private to DB zone (backend to database)"
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
# memorystore_psc_subnet_name은 terragrunt.hcl에서 자동 생성
memorystore_psc_connection_limit = 8
