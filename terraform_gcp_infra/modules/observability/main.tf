terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

locals {
  vm_instance_filter_regex_escaped   = replace(var.vm_instance_filter_regex, "\\", "\\\\")
  cloudsql_instance_regex_escaped    = replace(var.cloudsql_instance_regex, "\\", "\\\\")
  memorystore_instance_regex_escaped = replace(var.memorystore_instance_regex, "\\", "\\\\")
  lb_target_proxy_regex_escaped      = replace(var.lb_target_proxy_regex, "\\", "\\\\")
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

resource "google_monitoring_alert_policy" "vm_cpu_high" {
  count = var.enable_vm_cpu_alert && length(trimspace(var.vm_instance_filter_regex)) > 0 ? 1 : 0

  display_name = "VM CPU High"
  combiner     = "OR"

  conditions {
    display_name = "GCE CPU utilization"

    condition_threshold {
      filter = <<-EOT
metric.type="compute.googleapis.com/instance/cpu/utilization"
AND resource.type="gce_instance"
AND metric.label.instance_name=monitoring.regex.full_match("${local.vm_instance_filter_regex_escaped}")
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.vm_cpu_threshold
      duration        = var.vm_cpu_duration

      trigger {
        count = 1
      }

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.instance_id"]
      }
    }
  }

  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "cloudsql_cpu_high" {
  count = var.enable_cloudsql_cpu_alert && length(trimspace(var.cloudsql_instance_regex)) > 0 ? 1 : 0

  display_name = "Cloud SQL CPU High"
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL CPU utilization"

    condition_threshold {
      filter = <<-EOT
metric.type="cloudsql.googleapis.com/database/cpu/utilization"
AND resource.type="cloudsql_database"
AND resource.label.database_id=monitoring.regex.full_match("${local.cloudsql_instance_regex_escaped}")
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.cloudsql_cpu_threshold
      duration        = var.cloudsql_cpu_duration

      trigger {
        count = 1
      }

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.database_id"]
      }
    }
  }

  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "memorystore_memory_high" {
  count = var.enable_memorystore_memory_alert && length(trimspace(var.memorystore_instance_regex)) > 0 ? 1 : 0

  display_name = "Redis Memory Usage High"
  combiner     = "OR"

  conditions {
    display_name = "Redis memory usage ratio"

    condition_threshold {
      filter = <<-EOT
metric.type="redis.googleapis.com/stats/memory/usage_ratio"
AND resource.type="redis_instance"
AND resource.label.instance_id=monitoring.regex.full_match("${local.memorystore_instance_regex_escaped}")
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.memorystore_memory_threshold
      duration        = var.memorystore_memory_duration

      trigger {
        count = 1
      }

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.instance_id"]
      }
    }
  }

  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "lb_5xx_rate" {
  count = var.enable_lb_5xx_alert && length(trimspace(var.lb_target_proxy_regex)) > 0 ? 1 : 0

  display_name = "HTTPS LB 5xx Spike"
  combiner     = "OR"

  conditions {
    display_name = "Backend 5xx responses"

    condition_threshold {
      filter = <<-EOT
metric.type="loadbalancing.googleapis.com/https/request_count"
AND resource.type="https_lb_rule"
AND metric.label.response_code_class="500"
AND resource.label.target_proxy_name=monitoring.regex.full_match("${local.lb_target_proxy_regex_escaped}")
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.lb_5xx_threshold
      duration        = var.lb_5xx_duration

      trigger {
        count = 1
      }

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.target_proxy_name"]
      }
    }
  }

  notification_channels = var.notification_channels
}

output "log_sink_writer_identity" {
  value       = try(google_logging_project_sink.to_central[0].writer_identity, null)
  description = "중앙 버킷에 이 SA에 대한 권한을 부여해야 함"
}
