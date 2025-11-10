terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

}

provider "google" {
  project               = var.project_id
  user_project_override = true
  billing_project       = var.project_id
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
  # Merge environment-wide labels with per-module overrides
  default_labels = merge(module.naming.common_labels, var.default_labels)

  # Automatically derive bucket names when not explicitly provided
  assets_bucket_name  = length(trimspace(var.assets_bucket_name)) > 0 ? var.assets_bucket_name : "${module.naming.bucket_name_prefix}-assets"
  logs_bucket_name    = length(trimspace(var.logs_bucket_name)) > 0 ? var.logs_bucket_name : "${module.naming.bucket_name_prefix}-logs"
  backups_bucket_name = length(trimspace(var.backups_bucket_name)) > 0 ? var.backups_bucket_name : "${module.naming.bucket_name_prefix}-backups"

  # Merge bucket-specific labels with common labels
  assets_bucket_labels  = merge(module.naming.common_labels, { bucket = "assets" }, var.assets_bucket_labels)
  logs_bucket_labels    = merge(module.naming.common_labels, { bucket = "logs" }, var.logs_bucket_labels)
  backups_bucket_labels = merge(module.naming.common_labels, { bucket = "backups" }, var.backups_bucket_labels)
}

# Use gcs-root module to manage multiple buckets
module "game_storage" {
  source = "../../../../modules/gcs-root"

  project_id                       = var.project_id
  default_labels                   = local.default_labels
  default_kms_key_name             = var.kms_key_name
  default_public_access_prevention = var.public_access_prevention

  buckets = {
    assets = {
      name                        = local.assets_bucket_name
      location                    = var.assets_bucket_location
      storage_class               = var.assets_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = local.assets_bucket_labels

      enable_versioning = var.assets_enable_versioning
      lifecycle_rules   = var.assets_lifecycle_rules
      cors_rules        = var.assets_cors_rules
      iam_bindings      = var.assets_iam_bindings
    }

    logs = {
      name                        = local.logs_bucket_name
      location                    = var.logs_bucket_location
      storage_class               = var.logs_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = local.logs_bucket_labels

      enable_versioning       = var.logs_enable_versioning
      lifecycle_rules         = var.logs_lifecycle_rules
      cors_rules              = var.logs_cors_rules
      retention_policy_days   = var.logs_retention_policy_days
      retention_policy_locked = var.logs_retention_policy_locked
      iam_bindings            = var.logs_iam_bindings
    }

    backups = {
      name                        = local.backups_bucket_name
      location                    = var.backups_bucket_location
      storage_class               = var.backups_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = local.backups_bucket_labels

      enable_versioning       = var.backups_enable_versioning
      lifecycle_rules         = var.backups_lifecycle_rules
      cors_rules              = var.backups_cors_rules
      retention_policy_days   = var.backups_retention_policy_days
      retention_policy_locked = var.backups_retention_policy_locked
      iam_bindings            = var.backups_iam_bindings
    }
  }
}
