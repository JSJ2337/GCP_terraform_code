terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

module "obs" {
  source = "../../../modules/observability"

  project_id = var.project_id

  enable_central_log_sink = var.enable_central_log_sink
  central_logging_project = var.central_logging_project
  central_logging_bucket  = var.central_logging_bucket
  log_filter              = var.log_filter

  dashboard_json_files = var.dashboard_json_files
}
