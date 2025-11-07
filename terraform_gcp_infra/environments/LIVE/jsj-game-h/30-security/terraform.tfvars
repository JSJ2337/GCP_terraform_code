# Security Configuration
# Uncomment and set region to override the default from common.naming.tfvars.
# region = "asia-northeast3"

# IAM bindings (empty for now - add real users/groups later)
bindings = []

# Service accounts
create_service_accounts = true
# Leave service_accounts empty to use automatic names from modules/naming
service_accounts = []
