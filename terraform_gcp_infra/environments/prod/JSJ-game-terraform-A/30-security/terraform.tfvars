# Security Configuration
project_id = "jsj-game-terraform-a"

# IAM bindings (empty for now - add real users/groups later)
bindings = []

# Service accounts
create_service_accounts = true
service_accounts = [
  {
    account_id   = "jsj-game-a-compute"
    display_name = "JSJ Game A Compute Service Account"
    description  = "Service account for JSJ Game A compute instances"
  },
  {
    account_id   = "jsj-game-a-monitoring"
    display_name = "JSJ Game A Monitoring Service Account"
    description  = "Service account for JSJ Game A monitoring and logging"
  },
  {
    account_id   = "jsj-game-a-deployment"
    display_name = "JSJ Game A Deployment Service Account"
    description  = "Service account for JSJ Game A CI/CD deployments"
  }
]