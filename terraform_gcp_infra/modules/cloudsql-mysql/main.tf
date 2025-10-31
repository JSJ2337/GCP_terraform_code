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

# Logging flags for Cloud SQL
locals {
  # 기본 로깅 플래그 구성
  logging_flags = concat(
    var.enable_slow_query_log ? [
      { name = "slow_query_log", value = "on" },
      { name = "long_query_time", value = tostring(var.slow_query_log_time) }
    ] : [],
    var.enable_general_log ? [
      { name = "general_log", value = "on" }
    ] : [],
    [
      { name = "log_output", value = var.log_output }
    ]
  )

  # 사용자 정의 플래그와 로깅 플래그 병합
  all_database_flags = concat(var.database_flags, local.logging_flags)
}

# Cloud SQL MySQL Instance
resource "google_sql_database_instance" "instance" {
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    disk_autoresize   = var.disk_autoresize

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      binary_log_enabled             = var.binary_log_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.backup_retained_count
        retention_unit   = "COUNT"
      }
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = var.private_network
      # Note: require_ssl is deprecated in newer Google provider versions
      # Use SSL certificates and connection policies instead

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.cidr
        }
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }

    # Database flags (includes logging configuration)
    dynamic "database_flags" {
      for_each = local.all_database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    # Insights config
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length     = var.query_string_length
      record_application_tags = var.record_application_tags
    }

    user_labels = var.labels
  }

  lifecycle {
    ignore_changes = [
      settings[0].disk_size, # Allow disk autoresize
    ]
  }
}

# Databases
resource "google_sql_database" "databases" {
  for_each = { for db in var.databases : db.name => db }

  name      = each.value.name
  instance  = google_sql_database_instance.instance.name
  charset   = lookup(each.value, "charset", "utf8mb4")
  collation = lookup(each.value, "collation", "utf8mb4_unicode_ci")
  project   = var.project_id
}

# Users
resource "google_sql_user" "users" {
  for_each = { for user in var.users : user.name => user }

  name     = each.value.name
  instance = google_sql_database_instance.instance.name
  password = each.value.password
  host     = lookup(each.value, "host", "%")
  project  = var.project_id
}

# Read replicas (optional)
resource "google_sql_database_instance" "read_replicas" {
  for_each = var.read_replicas

  name                 = each.value.name
  master_instance_name = google_sql_database_instance.instance.name
  region               = each.value.region
  database_version     = var.database_version
  project              = var.project_id

  deletion_protection = var.deletion_protection

  replica_configuration {
    failover_target = lookup(each.value, "failover_target", false)
  }

  settings {
    tier              = each.value.tier
    availability_type = "ZONAL"
    disk_autoresize   = var.disk_autoresize

    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = var.private_network
      # require_ssl is deprecated in Google provider 7.x+
    }

    user_labels = var.labels
  }
}
