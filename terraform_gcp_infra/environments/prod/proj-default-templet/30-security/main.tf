terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  default_service_account_suffixes = ["compute", "monitoring", "deployment"]

  default_service_accounts = [
    for suffix in local.default_service_account_suffixes : {
      account_id   = "${local.sa_name_prefix}-${suffix}"
      display_name = "${title(replace(local.project_name, "-", " "))} ${title(replace(suffix, "-", " "))} Service Account"
      description  = "Service account for ${local.project_name} ${replace(suffix, "-", " ")} workloads"
    }
  ]

  service_accounts = length(var.service_accounts) > 0 ? var.service_accounts : local.default_service_accounts
}

module "iam" {
  source = "../../../../modules/iam"

  project_id = var.project_id

  bindings = var.bindings

  create_service_accounts = var.create_service_accounts
  service_accounts        = local.service_accounts
}
