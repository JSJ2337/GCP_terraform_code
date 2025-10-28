# Network Configuration
project_id   = "gcp-terraform-imsi"
vpc_name     = "game-a-vpc"
routing_mode = "GLOBAL"

# Subnets configuration
subnets = {
  "game-a-subnet-us-central1" = {
    region                = "us-central1"
    cidr                  = "10.1.0.0/20"
    private_google_access = true
    secondary_ranges = [
      {
        name = "game-a-pods"
        cidr = "10.1.16.0/20"
      },
      {
        name = "game-a-services"
        cidr = "10.1.32.0/20"
      }
    ]
  }
  "game-a-subnet-us-east1" = {
    region                = "us-east1"
    cidr                  = "10.2.0.0/20"
    private_google_access = true
    secondary_ranges      = []
  }
}

# NAT configuration
nat_region           = "us-central1"
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