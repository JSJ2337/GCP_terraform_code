# Security Configuration
project_id = "gcp-terraform-imsi"

# IAM bindings (empty for now - add real users/groups later)
bindings = []

# Service accounts
create_service_accounts = true
service_accounts = [
  {
    account_id   = "game-a-compute"
    display_name = "Game A Compute Service Account"
    description  = "Service account for Game A compute instances"
  },
  {
    account_id   = "game-a-monitoring"
    display_name = "Game A Monitoring Service Account"
    description  = "Service account for Game A monitoring and logging"
  },
  {
    account_id   = "game-a-deployment"
    display_name = "Game A Deployment Service Account"
    description  = "Service account for Game A CI/CD deployments"
  }
]