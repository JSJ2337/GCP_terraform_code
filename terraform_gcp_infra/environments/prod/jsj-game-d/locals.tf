# Common locals for naming and labeling conventions
locals {
  # Environment and project info
  environment    = "prod"
  project_name   = "game-d"
  organization   = "jsj"
  region_primary = "us-central1"
  region_backup  = "us-east1"

  # Naming prefix patterns (project-environment order)
  project_prefix  = "${local.project_name}-${local.environment}"
  resource_prefix = "${local.organization}-${local.project_name}-${local.environment}"

  # Common labels applied to all resources
  common_labels = {
    environment  = local.environment
    project      = local.project_name
    managed-by   = "terraform"
    cost-center  = "it-infra-deps"
    created-by   = "system-team"
    compliance   = "none"
  }

  # GCS bucket naming (must be globally unique, lowercase, hyphens)
  bucket_name_prefix = "${local.organization}-${local.project_name}-${local.environment}"

  # Network naming
  vpc_name            = "${local.project_prefix}-vpc"
  subnet_name_primary = "${local.project_prefix}-subnet-${local.region_primary}"
  subnet_name_backup  = "${local.project_prefix}-subnet-${local.region_backup}"
  pods_range_name     = "${local.project_prefix}-pods"
  services_range_name = "${local.project_prefix}-services"
  cloud_router_name   = "${local.vpc_name}-cr"
  cloud_nat_name      = "${local.vpc_name}-nat"

  # Compute naming
  vm_name_prefix         = "${local.project_prefix}-vm"
  instance_group_name    = "${local.project_prefix}-ig"
  instance_template_name = "${local.project_prefix}-template"

  # Database naming
  db_instance_name = "${local.project_prefix}-mysql"

  # Load Balancer naming
  backend_service_name = "${local.project_prefix}-backend"
  forwarding_rule_name = "${local.project_prefix}-lb"
  health_check_name    = "${local.project_prefix}-health"

  # Security naming
  sa_name_prefix   = "${local.project_prefix}-sa"
  kms_keyring_name = "${local.project_prefix}-keyring"

  # Common tags for firewall rules and instances
  common_tags = [
    local.environment,
    local.project_name,
  ]
}
