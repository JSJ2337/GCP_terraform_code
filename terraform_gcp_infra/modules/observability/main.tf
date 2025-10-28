terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

resource "google_logging_project_sink" "to_central" {
  count                  = var.enable_central_log_sink ? 1 : 0
  name                   = "to-central-${var.project_id}"
  destination            = "logging.googleapis.com/projects/${var.central_logging_project}/locations/global/buckets/${var.central_logging_bucket}"
  unique_writer_identity = true
  filter                 = var.log_filter
}

resource "google_monitoring_dashboard" "dashboards" {
  for_each       = { for d in var.dashboard_json_files : d => d }
  dashboard_json = file(each.value)
}

output "log_sink_writer_identity" {
  value       = try(google_logging_project_sink.to_central[0].writer_identity, null)
  description = "중앙 버킷에 이 SA에 대한 권한을 부여해야 함"
}
