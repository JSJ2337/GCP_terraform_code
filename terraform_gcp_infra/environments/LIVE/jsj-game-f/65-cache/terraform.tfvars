# Region & Project
# (project_id, project_name, environment, organization, region_primary, region_backup are in ../common.naming.tfvars)
# Note: For Redis, region must be a zone (e.g., us-central1-a), not a region
region = "us-central1-a"

# Memorystore configuration
# For development, use BASIC tier (no HA) to avoid zone configuration issues
alternative_location_id = ""
memory_size_gb          = 1
redis_version           = "REDIS_6_X"
tier                    = "BASIC"

# Networking (비워두면 naming 모듈 VPC 사용)
authorized_network = ""

# Display name (옵션)
display_name = "game-f dev redis"

# Maintenance window (옵션)
maintenance_window_day          = "SUNDAY"
maintenance_window_start_hour   = 2
maintenance_window_start_minute = 0

# 추가 라벨
labels = {
  tier = "cache"
  app  = "game-f"
}
