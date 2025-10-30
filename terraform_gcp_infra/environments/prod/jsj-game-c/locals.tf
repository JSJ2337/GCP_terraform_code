# Common locals for naming and labeling conventions
locals {
  # Environment and project info
  environment    = "prod"
  project_name   = "game-c"
  organization   = "jsj" # Update with your organization name
  region_primary = "us-central1"
  region_backup  = "us-east1"

  # Naming prefix patterns
  project_prefix  = "${local.environment}-${local.project_name}"
  resource_prefix = "${local.organization}-${local.environment}-${local.project_name}"

  # Common labels applied to all resources
  common_labels = {
    environment = local.environment
    project     = local.project_name
    managed_by  = "terraform"
    cost_center = "IT_infra_deps"
    created_by  = "system-team"
    compliance  = "none"
  }

  # GCS bucket naming (must be globally unique, lowercase, hyphens)
  bucket_name_prefix = "${local.organization}-${local.environment}-${local.project_name}"

  # Network naming
  vpc_name      = "${local.project_prefix}-vpc"
  subnet_prefix = "${local.project_prefix}-subnet"

  # Compute naming
  vm_name_prefix = "${local.project_prefix}-vm"

  # Security naming
  sa_name_prefix   = "${local.project_prefix}-sa"
  kms_keyring_name = "${local.project_prefix}-keyring"

  # Common tags for firewall rules and instances
  common_tags = [
    local.environment,
    local.project_name,
  ]
}
