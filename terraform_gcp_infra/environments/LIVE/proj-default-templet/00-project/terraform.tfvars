# Project Configuration
region = ""
folder_id       = null # No folder (standalone project)
billing_account = "01076D-327AD5-FC8922"

# Labels (only add extra labels here; modules/naming.common_labels will be merged)
labels = {
  team = "game-dev"
}

# APIs to enable
apis = [
  "compute.googleapis.com",
  "iam.googleapis.com",
  "servicenetworking.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "cloudkms.googleapis.com",
  "cloudbuild.googleapis.com",
  "container.googleapis.com",
  "sqladmin.googleapis.com",        # Cloud SQL
  "redis.googleapis.com"             # Memorystore Redis
]

# Budget settings
# Note: Budget API requires special quota project configuration
# Disabled by default to avoid authentication issues during deployment
# You can enable it manually via GCP Console: Billing → Budgets & alerts
enable_budget   = false
budget_amount   = 1000
budget_currency = "USD"

# Logging settings
log_retention_days = 90

# CMEK settings (optional)
# cmek_key_id = "projects/security-project/locations/us-central1/keyRings/main-ring/cryptoKeys/main-key"
