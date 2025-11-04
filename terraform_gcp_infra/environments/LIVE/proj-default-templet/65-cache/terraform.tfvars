# Region & Project
project_id     = "gcp-terraform-imsi"
project_name   = "default-templet"
environment    = "prod"
organization   = "myorg"
region_primary = "us-central1"
region_backup  = "us-east1"
region         = "us-central1"

# Memorystore configuration
alternative_location_id = "us-central1-b"
memory_size_gb          = 1
redis_version           = "REDIS_6_X"
tier                    = "STANDARD_HA"

# Networking (비워두면 naming 모듈 VPC 사용)
authorized_network = ""

# Display name (옵션)
display_name = "default-templet prod redis"

# Maintenance window (옵션)
maintenance_window_day          = "SUNDAY"
maintenance_window_start_hour   = 2
maintenance_window_start_minute = 0

# 추가 라벨
labels = {
  tier = "cache"
  app  = "default-templet"
}
