terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30"
    }
  }

  backend "gcs" {}
}

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

locals {
  region_effective = length(trimspace(var.region)) > 0 ? trimspace(var.region) : module.naming.region_primary
  private_network  = length(trimspace(var.private_network)) > 0 ? var.private_network : "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"
  labels           = merge(module.naming.common_labels, var.labels)
}

provider "google" {
  project = var.project_id
  region  = local.region_effective
}

provider "google-beta" {
  project = var.project_id
  region  = local.region_effective
}

module "mysql" {
  source = "../../../../modules/cloudsql-mysql"

  project_id    = var.project_id
  instance_name = module.naming.db_instance_name
  region        = local.region_effective

  database_version  = var.database_version
  tier              = var.tier
  availability_type = var.availability_type

  disk_size       = var.disk_size
  disk_type       = var.disk_type
  disk_autoresize = var.disk_autoresize

  deletion_protection = var.deletion_protection

  # Backup configuration
  backup_enabled                 = var.backup_enabled
  backup_start_time              = var.backup_start_time
  binary_log_enabled             = var.binary_log_enabled
  transaction_log_retention_days = var.transaction_log_retention_days
  backup_retained_count          = var.backup_retained_count

  # Network configuration
  ipv4_enabled    = var.ipv4_enabled
  private_network = local.private_network
  # require_ssl is deprecated in Google provider 7.x+
  authorized_networks = var.authorized_networks

  # Maintenance window
  maintenance_window_day          = var.maintenance_window_day
  maintenance_window_hour         = var.maintenance_window_hour
  maintenance_window_update_track = var.maintenance_window_update_track

  # Database flags
  database_flags = var.database_flags

  # Insights
  query_insights_enabled  = var.query_insights_enabled
  query_string_length     = var.query_string_length
  record_application_tags = var.record_application_tags

  # Logging
  enable_slow_query_log = var.enable_slow_query_log
  slow_query_log_time   = var.slow_query_log_time
  enable_general_log    = var.enable_general_log
  log_output            = var.log_output

  # Databases
  databases = var.databases

  # Users
  users = var.users

  # Read replicas
  read_replicas = var.read_replicas

  labels = local.labels
}
