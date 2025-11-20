# Storage configuration for default template

# Additional labels merged with modules/naming.common_labels
default_labels = {
  component = "storage"
}

# Common settings
uniform_bucket_level_access = true
public_access_prevention    = "enforced"
# kms_key_name = "projects/proj-default-templet-prod/locations/us-central1/keyRings/game-ring/cryptoKeys/storage-key"

# Assets bucket - for game assets, images, configurations
assets_bucket_location      = "US-CENTRAL1"
assets_bucket_storage_class = "STANDARD"
assets_bucket_labels = {
  bucket_type = "assets"
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

assets_iam_bindings = []

# Logs bucket - for application and system logs
logs_bucket_location      = "US-CENTRAL1"
logs_bucket_storage_class = "COLDLINE"
logs_enable_versioning    = false
logs_bucket_labels = {
  bucket_type = "logs"
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

logs_cors_rules   = []
logs_iam_bindings = []

# Backups bucket - for database and configuration backups
backups_bucket_location      = "US" # Multi-region for durability
backups_bucket_storage_class = "ARCHIVE"
backups_bucket_labels = {
  bucket_type = "backups"
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

backups_cors_rules   = []
backups_iam_bindings = []
