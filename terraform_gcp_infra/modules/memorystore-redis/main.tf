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
  alternative_location_id = length(trimspace(var.alternative_location_id)) > 0 ? trimspace(var.alternative_location_id) : ""
  maintenance_enabled     = var.maintenance_window_day != "" && var.maintenance_window_start_hour != null && var.maintenance_window_start_minute != null
  is_enterprise_tier      = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.tier)
  split_region            = split("-", var.region)
  enterprise_region       = length(local.split_region) > 2 ? join("-", slice(local.split_region, 0, length(local.split_region) - 1)) : var.region
}

resource "google_redis_instance" "standard" {
  count = local.is_enterprise_tier ? 0 : 1

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

  alternative_location_id = length(local.alternative_location_id) > 0 ? local.alternative_location_id : null

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
      condition     = var.tier != "STANDARD_HA" || length(local.alternative_location_id) > 0
      error_message = "STANDARD_HA tier requires alternative_location_id (e.g., us-central1-b)."
    }

    precondition {
      condition     = local.is_enterprise_tier || (var.replica_count == null && var.shard_count == null)
      error_message = "replica_count or shard_count can only be set for ENTERPRISE/ENTERPRISE_PLUS tiers."
    }
  }
}

resource "google_redis_cluster" "enterprise" {
  count = local.is_enterprise_tier ? 1 : 0

  project = var.project_id
  name    = var.instance_name
  region  = local.enterprise_region

  shard_count             = var.shard_count
  replica_count           = var.replica_count
  authorization_mode      = var.enterprise_authorization_mode
  transit_encryption_mode = var.enterprise_transit_encryption_mode
  node_type               = var.enterprise_node_type

  deletion_protection_enabled = var.deletion_protection

  redis_configs = var.enterprise_redis_configs

  psc_configs {
    network = var.authorized_network
  }

  dynamic "maintenance_policy" {
    for_each = local.maintenance_enabled ? [1] : []
    content {
      weekly_maintenance_window {
        day = upper(var.maintenance_window_day)
        start_time {
          hours   = var.maintenance_window_start_hour
          minutes = var.maintenance_window_start_minute
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.replica_count != null && var.replica_count >= 1
      error_message = "Enterprise tiers require replica_count to be set to 1 or greater."
    }

    precondition {
      condition     = var.shard_count != null && var.shard_count >= 1
      error_message = "Enterprise tiers require shard_count to be set to 1 or greater."
    }
  }
}
