terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

resource "google_storage_bucket" "bucket" {
  name                        = var.bucket_name
  location                    = var.location
  project                     = var.project_id
  storage_class               = var.storage_class
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = var.uniform_bucket_level_access

  labels = var.labels

  dynamic "versioning" {
    for_each = var.enable_versioning != null && var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      condition {
        age                   = lookup(lifecycle_rule.value.condition, "age", null)
        created_before        = lookup(lifecycle_rule.value.condition, "created_before", null)
        with_state            = lookup(lifecycle_rule.value.condition, "with_state", null)
        matches_storage_class = lookup(lifecycle_rule.value.condition, "matches_storage_class", null)
        num_newer_versions    = lookup(lifecycle_rule.value.condition, "num_newer_versions", null)
      }

      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lookup(lifecycle_rule.value.action, "storage_class", null)
      }
    }
  }

  dynamic "retention_policy" {
    for_each = var.retention_policy_days == null ? [] : (
      var.retention_policy_days > 0 ? [1] : []
    )
    content {
      retention_period = var.retention_policy_days * 24 * 60 * 60 # 일 단위를 초로 변환
      is_locked        = var.retention_policy_locked
    }
  }

  dynamic "encryption" {
    for_each = var.kms_key_name != null && var.kms_key_name != "" ? [1] : []
    content {
      default_kms_key_name = var.kms_key_name
    }
  }

  dynamic "logging" {
    for_each = var.access_log_bucket != null && var.access_log_bucket != "" ? [1] : []
    content {
      log_bucket        = var.access_log_bucket
      log_object_prefix = var.access_log_prefix
    }
  }

  dynamic "website" {
    for_each = (var.website_main_page_suffix != null && var.website_main_page_suffix != "") || (var.website_not_found_page != null && var.website_not_found_page != "") ? [1] : []
    content {
      main_page_suffix = var.website_main_page_suffix != null ? var.website_main_page_suffix : ""
      not_found_page   = var.website_not_found_page != null ? var.website_not_found_page : ""
    }
  }

  dynamic "cors" {
    for_each = var.cors_rules != null ? var.cors_rules : []
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = lookup(cors.value, "response_header", null)
      max_age_seconds = lookup(cors.value, "max_age_seconds", null)
    }
  }

  public_access_prevention = var.public_access_prevention
}

# 버킷 IAM 멤버 (비권한형 관리)
resource "google_storage_bucket_iam_member" "members" {
  for_each = {
    for idx, binding in flatten([
      for b in var.iam_bindings : [
        for member in b.members : {
          role      = b.role
          member    = member
          condition = lookup(b, "condition", null)
          key       = "${b.role}-${member}"
        }
      ]
    ]) : binding.key => binding
  }

  bucket = google_storage_bucket.bucket.name
  role   = each.value.role
  member = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# 알림 구성
resource "google_storage_notification" "notifications" {
  for_each = var.notifications != null ? { for idx, notif in var.notifications : idx => notif } : {}

  bucket         = google_storage_bucket.bucket.name
  payload_format = each.value.payload_format
  topic          = each.value.topic

  event_types        = lookup(each.value, "event_types", ["OBJECT_FINALIZE"])
  object_name_prefix = lookup(each.value, "object_name_prefix", null)
  custom_attributes  = lookup(each.value, "custom_attributes", {})
}
