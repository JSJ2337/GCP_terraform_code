# Network Configuration
# region overrides the default from common.naming.tfvars when set.
# region = "asia-northeast3"
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/WAS/DB zones)
additional_subnets = [
  {
    name   = "game-n-subnet-dmz"
    region = "asia-northeast3"
    cidr   = "10.3.0.0/24"
  },
  {
    name   = "game-n-subnet-private"
    region = "asia-northeast3"
    cidr   = "10.3.1.0/24"
  },
  {
    name   = "game-n-subnet-db"
    region = "asia-northeast3"
    cidr   = "10.3.2.0/24"
  }
]

dmz_subnet_name     = "game-n-subnet-dmz"
private_subnet_name = "game-n-subnet-private"
db_subnet_name      = "game-n-subnet-db"

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
enable_memorystore_psc_policy    = true
memorystore_psc_region           = "asia-northeast3"
memorystore_psc_subnet_name      = "game-n-subnet-private"
memorystore_psc_connection_limit = 8
