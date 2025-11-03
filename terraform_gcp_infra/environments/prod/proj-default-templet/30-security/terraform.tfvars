# Security Configuration
project_id     = "gcp-terraform-imsi"
project_name   = "default-templet"
environment    = "prod"
organization   = "myorg"
region_primary = "us-central1"
region_backup  = "us-east1"
region         = "us-central1"

# IAM bindings (empty for now - add real users/groups later)
bindings = []

# Service accounts
create_service_accounts = true
# Leave service_accounts empty to use automatic names from modules/naming
service_accounts = []
