# Storage Configuration for Game A Production
project_id = "gcp-terraform-imsi"

# Default labels for all buckets
default_labels = {
  environment = "prod"
  project     = "default-templet"
  managed_by  = "terraform"
}

# Common settings
uniform_bucket_level_access = true
public_access_prevention    = "enforced"
# kms_key_name = "projects/proj-default-templet-prod/locations/us-central1/keyRings/game-ring/cryptoKeys/storage-key"

# Assets bucket - for game assets, images, configurations
assets_bucket_name          = "gcp-tf-imsi-assets-prod"
assets_bucket_location      = "US-CENTRAL1"
assets_bucket_storage_class = "STANDARD"
assets_bucket_labels = {
  type        = "assets"
  game        = "default-templet"
  environment = "prod"
  managed-by  = "terraform"
}

assets_enable_versioning = true

assets_lifecycle_rules = [
  {
    condition = {
      age = 365 # 1 year
    }
    action = {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  },
  {
    condition = {
      age = 1095 # 3 years
    }
    action = {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
]

# CORS for web game access
assets_cors_rules = [
  {
    origin          = ["https://default-templet.example.com", "https://cdn.default-templet.example.com"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }
]

assets_iam_bindings = []

# Logs bucket - for application and system logs
logs_bucket_name          = "gcp-tf-imsi-logs-prod"
logs_bucket_location      = "US-CENTRAL1"
logs_bucket_storage_class = "COLDLINE"
logs_bucket_labels = {
  type        = "logs"
  game        = "default-templet"
  environment = "prod"
  managed-by  = "terraform"
}

logs_lifecycle_rules = [
  {
    condition = {
      age = 90 # 3 months
    }
    action = {
      type = "Delete"
    }
  }
]

logs_retention_policy_days   = 2555 # 7 years for compliance
logs_retention_policy_locked = true

logs_iam_bindings = []

# Backups bucket - for database and configuration backups
backups_bucket_name          = "gcp-tf-imsi-backups-prod"
backups_bucket_location      = "US" # Multi-region for durability
backups_bucket_storage_class = "ARCHIVE"
backups_bucket_labels = {
  type        = "backups"
  game        = "default-templet"
  environment = "prod"
  managed-by  = "terraform"
}

backups_enable_versioning = true

backups_lifecycle_rules = [
  {
    condition = {
      num_newer_versions = 5 # Keep only 5 versions
    }
    action = {
      type = "Delete"
    }
  }
]

backups_retention_policy_days   = 3650 # 10 years
backups_retention_policy_locked = true

backups_iam_bindings = []