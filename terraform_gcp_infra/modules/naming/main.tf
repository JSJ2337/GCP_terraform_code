locals {
  project_prefix  = "${var.project_name}-${var.environment}"
  resource_prefix = "${var.organization}-${var.project_name}-${var.environment}"

  bucket_name_prefix = local.resource_prefix

  vpc_name            = "${local.project_prefix}-vpc"
  subnet_name_primary = "${local.project_prefix}-subnet-${var.region_primary}"
  subnet_name_backup  = "${local.project_prefix}-subnet-${var.region_backup}"
  pods_range_name     = "${local.project_prefix}-pods"
  services_range_name = "${local.project_prefix}-services"
  cloud_router_name   = "${local.vpc_name}-cr"
  cloud_nat_name      = "${local.vpc_name}-nat"

  vm_name_prefix         = "${local.project_prefix}-vm"
  instance_group_name    = "${local.project_prefix}-ig"
  instance_template_name = "${local.project_prefix}-template"

  db_instance_name = "${local.project_prefix}-mysql"

  backend_service_name = "${local.project_prefix}-backend"
  forwarding_rule_name = "${local.project_prefix}-lb"
  health_check_name    = "${local.project_prefix}-health"

  sa_name_prefix   = "${local.project_prefix}-sa"
  kms_keyring_name = "${local.project_prefix}-keyring"

  default_zone = "${var.region_primary}-${var.default_zone_suffix}"

  common_labels = merge(
    var.base_labels,
    {
      environment = var.environment
      project     = var.project_name
    }
  )

  common_tags = distinct(concat([var.environment, var.project_name], var.extra_tags))
}
