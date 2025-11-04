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
  alternative_location_id = length(trimspace(var.alternative_location_id)) > 0 ? var.alternative_location_id : null
  maintenance_enabled     = var.maintenance_window_day != "" && var.maintenance_window_start_hour != null && var.maintenance_window_start_minute != null
}

resource "google_redis_instance" "this" {
  project = var.project_id
  name    = var.instance_name

  tier                    = var.tier
  memory_size_gb          = var.memory_size_gb
  redis_version           = var.redis_version
  location_id             = var.region
  connect_mode            = var.connect_mode
  labels                  = var.labels
  authorized_network      = var.authorized_network
  transit_encryption_mode = var.transit_encryption_mode

  display_name = length(trimspace(var.display_name)) > 0 ? var.display_name : null

  alternative_location_id = local.alternative_location_id

  dynamic "maintenance_policy" {
    for_each = local.maintenance_enabled ? [1] : []
    content {
      weekly_maintenance_window {
        day = var.maintenance_window_day
        start_time {
          hours   = var.maintenance_window_start_hour
          minutes = var.maintenance_window_start_minute
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.tier != "STANDARD_HA" || local.alternative_location_id != null
      error_message = "STANDARD_HA tier requires alternative_location_id (e.g., us-central1-b)."
    }
  }
}
