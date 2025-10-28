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
  region  = "us-central1"
}

module "iam" {
  source = "../../../../modules/iam"

  project_id = var.project_id

  bindings = var.bindings

  create_service_accounts = var.create_service_accounts
  service_accounts        = var.service_accounts
}
