variable "project_id" {
  type        = string
  description = "The project ID to create buckets in"
}

variable "default_labels" {
  type        = map(string)
  description = "Default labels to apply to all buckets"
  default     = {}
}

variable "default_kms_key_name" {
  type        = string
  description = "Default KMS key name for bucket encryption"
  default     = ""
}

variable "default_public_access_prevention" {
  type        = string
  description = "Default public access prevention setting"
  default     = "enforced"
  validation {
    condition = contains([
      "enforced", "inherited"
    ], var.default_public_access_prevention)
    error_message = "Public access prevention must be 'enforced' or 'inherited'."
  }
}

variable "buckets" {
  type = map(object({
    name                        = string
    location                    = optional(string)
    storage_class               = optional(string)
    force_destroy               = optional(bool)
    uniform_bucket_level_access = optional(bool)
    labels                      = optional(map(string))

    enable_versioning = optional(bool)
    lifecycle_rules = optional(list(object({
      condition = object({
        age                   = optional(number)
        created_before        = optional(string)
        with_state            = optional(string)
        matches_storage_class = optional(list(string))
        num_newer_versions    = optional(number)
      })
      action = object({
        type          = string
        storage_class = optional(string)
      })
    })))
    retention_policy_days   = optional(number)
    retention_policy_locked = optional(bool)
    kms_key_name            = optional(string)

    access_log_bucket = optional(string)
    access_log_prefix = optional(string)

    website_main_page_suffix = optional(string)
    website_not_found_page   = optional(string)

    cors_rules = optional(list(object({
      origin          = list(string)
      method          = list(string)
      response_header = optional(list(string))
      max_age_seconds = optional(number)
    })))
    public_access_prevention = optional(string)

    iam_bindings = optional(list(object({
      role    = string
      members = list(string)
      condition = optional(object({
        title       = string
        description = optional(string)
        expression  = string
      }))
    })))
    notifications = optional(list(object({
      topic              = string
      payload_format     = string
      event_types        = optional(list(string))
      object_name_prefix = optional(string)
      custom_attributes  = optional(map(string))
    })))
  }))
  description = "Map of bucket configurations"
}