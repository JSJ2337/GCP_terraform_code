# Cloud SQL Configuration
# Instance name format: {project_name}-{environment}-{db_suffix}
# Example: myproj-live-gdb, myproj-qa-dev-ldb

# DB instance suffix (구분 용도에 따라 변경)
db_suffix = "mysql"  # gdb (game db), ldb (log db), udb (user db) 등

# Instance configuration (Terragrunt supplies region_primary by default)
# region            = "asia-northeast3"
database_version  = "MYSQL_8_0"
tier              = "db-n1-standard-1"
edition           = "ENTERPRISE"  # Cloud SQL Edition (ENTERPRISE, ENTERPRISE_PLUS)
availability_type = "REGIONAL" # Live 기본값 (qa-dev 환경 시 ZONAL로 조정)

# Disk configuration
disk_size       = 20
disk_type       = "PD_SSD"
disk_autoresize = true

# Deletion protection (Live: true, qa-dev: false)
deletion_protection = false # 삭제 보호 기본 비활성 (필요 시 true로 변경)

# Backup configuration
backup_enabled                 = true
backup_start_time              = "03:00"
binary_log_enabled             = true
transaction_log_retention_days = 7
backup_retained_count          = 7

# Network configuration
# Use private IP; leave private_network empty to let modules/naming derive the VPC self-link
ipv4_enabled        = false # Use Private IP
authorized_networks = []

# Maintenance window
maintenance_window_day          = 7 # Sunday
maintenance_window_hour         = 3 # 03:00
maintenance_window_update_track = "stable"

# Database flags (optional)
database_flags = []

# Query Insights
query_insights_enabled  = true
query_string_length     = 1024
record_application_tags = false

# Logging configuration
enable_slow_query_log = true   # Enable slow query logging
slow_query_log_time   = 2      # Queries taking longer than 2 seconds
enable_general_log    = false  # Log all queries (Live: false, qa-dev: true)
log_output            = "FILE" # FILE (send to Cloud Logging) or TABLE

# Databases to create
databases = []

# Users to create
# IMPORTANT: Store passwords in Secret Manager
users = []

# Read replicas (optional)
# region은 terragrunt.hcl에서 자동으로 region_primary 사용
# 필요시 개별 replica에 다른 region 명시 가능 (예: DR용)
read_replicas = {
  replica1 = {
    # region 미지정 시 Master와 같은 리전(region_primary) 자동 사용
    tier              = "db-n1-standard-1"
    availability_type = "ZONAL" # Read Replica는 ZONAL만 가능
    # Optional overrides per replica:
    # region = "asia-northeast1"  # DR용 다른 리전 지정 시
    # disk_size         = 50
    # disk_type         = "PD_SSD"
    # private_network   = "projects/host/global/networks/shared-vpc"
    # maintenance_window_day  = 1
    # maintenance_window_hour = 4
    labels = {
      role = "read"
    }
  }
}

# Labels (will be merged with common_labels from modules/naming)
labels = {
  tier = "database"
}
