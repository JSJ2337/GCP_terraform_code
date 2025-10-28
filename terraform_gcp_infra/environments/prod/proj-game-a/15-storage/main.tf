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
  project = var.project_id
}

# Use gcs-root module to manage multiple buckets
module "game_storage" {
  source = "../../../modules/gcs-root"

  project_id                       = var.project_id
  default_labels                   = var.default_labels
  default_kms_key_name             = var.kms_key_name
  default_public_access_prevention = var.public_access_prevention

  buckets = {
    assets = {
      name                        = var.assets_bucket_name
      location                    = var.assets_bucket_location
      storage_class               = var.assets_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = var.assets_bucket_labels

      enable_versioning = var.assets_enable_versioning
      lifecycle_rules   = var.assets_lifecycle_rules
      cors_rules        = var.assets_cors_rules
      iam_bindings      = var.assets_iam_bindings
    }

    logs = {
      name                        = var.logs_bucket_name
      location                    = var.logs_bucket_location
      storage_class               = var.logs_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = var.logs_bucket_labels

      lifecycle_rules         = var.logs_lifecycle_rules
      retention_policy_days   = var.logs_retention_policy_days
      retention_policy_locked = var.logs_retention_policy_locked
      iam_bindings            = var.logs_iam_bindings
    }

    backups = {
      name                        = var.backups_bucket_name
      location                    = var.backups_bucket_location
      storage_class               = var.backups_bucket_storage_class
      uniform_bucket_level_access = var.uniform_bucket_level_access
      labels                      = var.backups_bucket_labels

      enable_versioning       = var.backups_enable_versioning
      lifecycle_rules         = var.backups_lifecycle_rules
      retention_policy_days   = var.backups_retention_policy_days
      retention_policy_locked = var.backups_retention_policy_locked
      iam_bindings            = var.backups_iam_bindings
    }
  }
}