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

}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

## Bootstrap remote state for folder structure (optional, when using dynamic folders)
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.bootstrap_state_bucket
    prefix = var.bootstrap_state_prefix
  }
}

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name != "" ? var.project_name : var.project_id
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

module "project_base" {
  source = "../../../../modules/project-base"

  project_id   = var.project_id
  project_name = var.project_name != "" ? var.project_name : module.naming.project_name
  # Prefer dynamic folder from bootstrap remote state when folder_id is not provided
  # environment_folder_ids 키 형식: "product/region/env" (예: "gcp-gcby/us-west1/LIVE")
  folder_id = var.folder_id != null ? var.folder_id : data.terraform_remote_state.bootstrap.outputs.environment_folder_ids["${var.folder_product}/${var.folder_region}/${var.folder_env}"]
  # When using folders, org_id should be null
  org_id          = var.folder_id != null ? var.org_id : null
  billing_account = var.billing_account
  labels          = merge(module.naming.common_labels, var.labels)

  apis               = var.apis
  enable_budget      = var.enable_budget
  budget_amount      = var.budget_amount
  budget_currency    = var.budget_currency
  log_retention_days = var.log_retention_days
  cmek_key_id        = var.cmek_key_id

  # Logging bucket management toggles
  manage_default_logging_bucket = var.manage_default_logging_bucket
  logging_api_wait_duration     = var.logging_api_wait_duration
}
