# Project Configuration
project_id      = "jsj-game-terraform-a"
project_name    = "JSJ Game Terraform A"
folder_id       = null # No folder (standalone project)
billing_account = "01076D-327AD5-FC8922"

# Labels
labels = {
  environment = "prod"
  project     = "jsj-game-a"
  team        = "game-dev"
  cost-center = "engineering"
  created_by  = "platform-team"
  managed_by  = "terraform"
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
enable_budget   = true
budget_amount   = 1000
budget_currency = "USD"

# Logging settings
log_retention_days = 90

# CMEK settings (optional)
# cmek_key_id = "projects/security-project/locations/us-central1/keyRings/main-ring/cryptoKeys/main-key"