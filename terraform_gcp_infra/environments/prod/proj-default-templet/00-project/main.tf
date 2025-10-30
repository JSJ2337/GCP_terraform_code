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
  region  = "us-central1"
}

provider "google-beta" {
  project = var.project_id
  region  = "us-central1"
}

# Common locals - shared across all layers
locals {
  common_labels = {
    environment = "prod"
    project     = "default-templet"
    managed_by  = "terraform"
    cost_center = "gaming"
    created_by  = "platform-team"
  }
}

module "project_base" {
  source = "../../../../modules/project-base"

  project_id      = var.project_id
  project_name    = var.project_name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = merge(local.common_labels, var.labels)

  apis               = var.apis
  enable_budget      = var.enable_budget
  budget_amount      = var.budget_amount
  budget_currency    = var.budget_currency
  log_retention_days = var.log_retention_days
  cmek_key_id        = var.cmek_key_id
}
