# Storage Configuration for Game A Production
project_id = "proj-game-a-prod"

# Common settings
uniform_bucket_level_access = true
public_access_prevention    = "enforced"
# kms_key_name = "projects/proj-game-a-prod/locations/us-central1/keyRings/game-ring/cryptoKeys/storage-key"

# Assets bucket - for game assets, images, configurations
assets_bucket_name          = "proj-game-a-assets-prod"
assets_bucket_location      = "US-CENTRAL1"
assets_bucket_storage_class = "STANDARD"
assets_bucket_labels = {
  type        = "assets"
  game        = "game-a"
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
    origin          = ["https://game-a.example.com", "https://cdn.game-a.example.com"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }
]

assets_iam_bindings = [
  {
    role = "roles/storage.objectViewer"
    members = [
      "serviceAccount:game-a-compute@proj-game-a-prod.iam.gserviceaccount.com",
      "serviceAccount:game-a-cdn@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  },
  {
    role = "roles/storage.objectCreator"
    members = [
      "serviceAccount:game-a-deployment@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  }
]

# Logs bucket - for application and system logs
logs_bucket_name          = "proj-game-a-logs-prod"
logs_bucket_location      = "US-CENTRAL1"
logs_bucket_storage_class = "COLDLINE"
logs_bucket_labels = {
  type        = "logs"
  game        = "game-a"
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

logs_iam_bindings = [
  {
    role = "roles/storage.objectCreator"
    members = [
      "serviceAccount:game-a-compute@proj-game-a-prod.iam.gserviceaccount.com",
      "serviceAccount:game-a-monitoring@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  },
  {
    role = "roles/storage.objectViewer"
    members = [
      "group:game-ops-team@company.com",
      "serviceAccount:game-a-monitoring@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  }
]

# Backups bucket - for database and configuration backups
backups_bucket_name          = "proj-game-a-backups-prod"
backups_bucket_location      = "US" # Multi-region for durability
backups_bucket_storage_class = "ARCHIVE"
backups_bucket_labels = {
  type        = "backups"
  game        = "game-a"
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

backups_iam_bindings = [
  {
    role = "roles/storage.objectCreator"
    members = [
      "serviceAccount:game-a-backup@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  },
  {
    role = "roles/storage.objectViewer"
    members = [
      "group:game-ops-team@company.com",
      "serviceAccount:game-a-backup@proj-game-a-prod.iam.gserviceaccount.com"
    ]
  }
]