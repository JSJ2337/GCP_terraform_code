# Project Configuration
project_id      = "gcp-terraform-imsi"
project_name    = "gcp-terraform-imsi"
folder_id       = null # No folder (standalone project)
billing_account = "01076D-327AD5-FC8922"

# Labels
labels = {
  environment = "prod"
  project     = "game-a"
  team        = "game-dev"
  cost-center = "engineering"
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
  "container.googleapis.com"
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