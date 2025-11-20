terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

# 구성값에 맞춰 여러 GCS 버킷을 한 번에 생성
module "gcs_buckets" {
  source = "../gcs-bucket"

  for_each = var.buckets

  project_id                  = var.project_id
  bucket_name                 = each.value.name
  location                    = lookup(each.value, "location", "US")
  storage_class               = lookup(each.value, "storage_class", "STANDARD")
  force_destroy               = lookup(each.value, "force_destroy", false)
  uniform_bucket_level_access = lookup(each.value, "uniform_bucket_level_access", true)
  labels                      = merge(var.default_labels, lookup(each.value, "labels", {}))

  enable_versioning       = lookup(each.value, "enable_versioning", false)
  lifecycle_rules         = lookup(each.value, "lifecycle_rules", [])
  retention_policy_days   = lookup(each.value, "retention_policy_days", 0)
  retention_policy_locked = lookup(each.value, "retention_policy_locked", false)
  kms_key_name            = lookup(each.value, "kms_key_name", var.default_kms_key_name)

  access_log_bucket = lookup(each.value, "access_log_bucket", "")
  access_log_prefix = lookup(each.value, "access_log_prefix", "")

  website_main_page_suffix = lookup(each.value, "website_main_page_suffix", "")
  website_not_found_page   = lookup(each.value, "website_not_found_page", "")

  cors_rules               = lookup(each.value, "cors_rules", [])
  public_access_prevention = lookup(each.value, "public_access_prevention", var.default_public_access_prevention)

  iam_bindings  = lookup(each.value, "iam_bindings", [])
  notifications = lookup(each.value, "notifications", [])
}
