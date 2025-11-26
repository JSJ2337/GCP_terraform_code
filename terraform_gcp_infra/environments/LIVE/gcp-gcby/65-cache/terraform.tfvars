# Region & Project
# IMPORTANT: Redis location_id requires a ZONE (e.g., us-central1-a), not a region.
# Terragrunt supplies region_primary by default; override with a zone if needed.
# region         = "asia-northeast3-a"

# Memorystore configuration
alternative_location_id     = ""
alternative_location_suffix = "b"
memory_size_gb              = 8  # 8GB 메모리 (자동으로 ~4 vCPU 할당)
redis_version               = "REDIS_7_2"  # Redis 7.2 (최신 안정 버전)
tier                        = "ENTERPRISE"
replica_count               = 1
shard_count                 = 1

# Deletion protection (Production: true, Development/Test: false)
deletion_protection = false

# Networking (비워두면 naming 모듈 VPC 사용)
authorized_network = ""

# Enterprise는 PSC만 지원
connect_mode = "PRIVATE_SERVICE_CONNECT"

# Display name (옵션)
display_name = "gcby live redis"

# Maintenance window (옵션)
maintenance_window_day          = "SUNDAY"
maintenance_window_start_hour   = 2
maintenance_window_start_minute = 0

# 추가 라벨
labels = {
  tier = "cache"
  app  = "gcby"
}
