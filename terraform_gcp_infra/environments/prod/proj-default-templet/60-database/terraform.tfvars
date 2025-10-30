# Cloud SQL Configuration
# Instance name is auto-generated from ../locals.tf (db_instance_name)
project_id = "gcp-terraform-imsi"

# Instance configuration
region            = "us-central1"
database_version  = "MYSQL_8_0"
tier              = "db-n1-standard-1"
availability_type = "ZONAL" # Production: REGIONAL, Development: ZONAL

# Disk configuration
disk_size       = 20
disk_type       = "PD_SSD"
disk_autoresize = true

# Deletion protection (Production: true, Development: false)
deletion_protection = false # Set to true for production

# Backup configuration
backup_enabled                     = true
backup_start_time                  = "03:00"
point_in_time_recovery_enabled     = true
transaction_log_retention_days     = 7
backup_retained_count              = 7

# Network configuration
ipv4_enabled        = false # Use Private IP
private_network     = "" # Will be set after VPC is created
authorized_networks = []

# Maintenance window
maintenance_window_day          = 7  # Sunday
maintenance_window_hour         = 3  # 03:00
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
enable_general_log    = false  # Log all queries (Production: false, Debug: true)
log_output            = "FILE" # FILE (send to Cloud Logging) or TABLE

# Databases to create
databases = []

# Users to create
# IMPORTANT: Store passwords in Secret Manager
users = []

# Read replicas (optional)
read_replicas = {}

# Labels (will be merged with common_labels from locals.tf)
labels = {
  tier = "database"
}
