# Project Configuration
project_id      = "proj-game-a-prod"
project_name    = "Game A Production"
folder_id       = "folders/123456789012" # Replace with actual folder ID
billing_account = "012345-678901-234567" # Replace with actual billing account

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
enable_budget   = true
budget_amount   = 1000
budget_currency = "USD"

# Logging settings
log_retention_days = 90

# CMEK settings (optional)
# cmek_key_id = "projects/security-project/locations/us-central1/keyRings/main-ring/cryptoKeys/main-key"