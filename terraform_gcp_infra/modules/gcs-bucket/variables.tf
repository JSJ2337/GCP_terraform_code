variable "project_id" {
  type        = string
  description = "The project ID to create the bucket in"
}

variable "bucket_name" {
  type        = string
  description = "The name of the bucket"
}

variable "location" {
  type        = string
  description = "The location of the bucket"
  default     = "US"
}

variable "storage_class" {
  type        = string
  description = "The storage class of the bucket"
  default     = "STANDARD"
  validation {
    condition = contains([
      "STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"
    ], var.storage_class)
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "force_destroy" {
  type        = bool
  description = "When deleting a bucket, this boolean option will delete all contained objects"
  default     = false
}

variable "uniform_bucket_level_access" {
  type        = bool
  description = "Enables uniform bucket-level access on a bucket"
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "A map of labels to assign to the bucket"
  default     = {}
}

variable "enable_versioning" {
  type        = bool
  description = "Enable versioning on the bucket"
  default     = false
}

variable "lifecycle_rules" {
  type = list(object({
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
  }))
  description = "Lifecycle rules for the bucket"
  default     = []
}

variable "retention_policy_days" {
  type        = number
  description = "Retention policy in days. Set to 0 to disable"
  default     = 0
}

variable "retention_policy_locked" {
  type        = bool
  description = "Whether the retention policy is locked"
  default     = false
}

variable "kms_key_name" {
  type        = string
  description = "The KMS key name for default encryption"
  default     = ""
}

variable "access_log_bucket" {
  type        = string
  description = "The bucket to store access logs in"
  default     = ""
}

variable "access_log_prefix" {
  type        = string
  description = "The prefix for access log objects"
  default     = ""
}

variable "website_main_page_suffix" {
  type        = string
  description = "The suffix for the main page of a static website"
  default     = ""
}

variable "website_not_found_page" {
  type        = string
  description = "The custom 404 page for a static website"
  default     = ""
}

variable "cors_rules" {
  type = list(object({
    origin          = list(string)
    method          = list(string)
    response_header = optional(list(string))
    max_age_seconds = optional(number)
  }))
  description = "CORS configuration for the bucket"
  default     = []
}

variable "public_access_prevention" {
  type        = string
  description = "Prevents public access to a bucket"
  default     = "enforced"
  validation {
    condition = var.public_access_prevention == null || contains([
      "enforced", "inherited"
    ], var.public_access_prevention)
    error_message = "Public access prevention must be 'enforced' or 'inherited'."
  }
}

variable "iam_bindings" {
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  description = "IAM bindings for the bucket"
  default     = []
}

variable "notifications" {
  type = list(object({
    topic              = string
    payload_format     = string
    event_types        = optional(list(string))
    object_name_prefix = optional(string)
    custom_attributes  = optional(map(string))
  }))
  description = "Pub/Sub notifications for the bucket"
  default     = []
}