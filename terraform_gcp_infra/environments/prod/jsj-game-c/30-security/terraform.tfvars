# Security Configuration
project_id = "jsj-prod-game-c"

# IAM bindings (empty for now - add real users/groups later)
bindings = []

# Service accounts
create_service_accounts = true
service_accounts = [
  {
    account_id   = "default-templet-compute"
    display_name = "Game A Compute Service Account"
    description  = "Service account for Game A compute instances"
  },
  {
    account_id   = "default-templet-monitoring"
    display_name = "Game A Monitoring Service Account"
    description  = "Service account for Game A monitoring and logging"
  },
  {
    account_id   = "default-templet-deployment"
    display_name = "Game A Deployment Service Account"
    description  = "Service account for Game A CI/CD deployments"
  }
]