# Security Configuration
project_id = "proj-game-a-prod"

# IAM bindings
bindings = [
  {
    role   = "roles/compute.instanceAdmin.v1"
    member = "group:game-dev-team@company.com"
  },
  {
    role   = "roles/monitoring.viewer"
    member = "group:game-ops-team@company.com"
  },
  {
    role   = "roles/logging.viewer"
    member = "group:game-ops-team@company.com"
  }
]

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