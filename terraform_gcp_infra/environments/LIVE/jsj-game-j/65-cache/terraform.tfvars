# Region & Project
# IMPORTANT: Redis location_id requires a ZONE (e.g., us-central1-a), not a region.
# Terragrunt supplies region_primary by default; override with a zone if needed.
# region         = "asia-northeast3-a"

# Memorystore configuration
alternative_location_id     = ""
alternative_location_suffix = "b"
memory_size_gb              = 1
redis_version               = "REDIS_6_X"
tier                        = "STANDARD_HA"

# Networking (비워두면 naming 모듈 VPC 사용)
authorized_network = ""

# Display name (옵션)
display_name = "game-j prod redis"

# Maintenance window (옵션)
maintenance_window_day          = "SUNDAY"
maintenance_window_start_hour   = 2
maintenance_window_start_minute = 0

# 추가 라벨
labels = {
  tier = "cache"
  app  = "game-j"
}
