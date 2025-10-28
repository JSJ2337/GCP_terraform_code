variable "project_id" {
  type        = string
  description = "The project ID"
}

# Common settings
variable "default_labels" {
  type        = map(string)
  description = "Default labels to apply to all buckets"
  default     = {}
}

variable "uniform_bucket_level_access" {
  type        = bool
  description = "Enable uniform bucket-level access"
  default     = true
}

variable "public_access_prevention" {
  type        = string
  description = "Public access prevention setting"
  default     = "enforced"
}

variable "kms_key_name" {
  type        = string
  description = "KMS key name for encryption"
  default     = ""
}

# Assets bucket configuration
variable "assets_bucket_name" {
  type        = string
  description = "Name for the assets bucket"
}

variable "assets_bucket_location" {
  type        = string
  description = "Location for the assets bucket"
  default     = "US-CENTRAL1"
}

variable "assets_bucket_storage_class" {
  type        = string
  description = "Storage class for the assets bucket"
  default     = "STANDARD"
}

variable "assets_bucket_labels" {
  type        = map(string)
  description = "Labels for the assets bucket"
  default     = {}
}

variable "assets_enable_versioning" {
  type        = bool
  description = "Enable versioning for assets bucket"
  default     = true
}

variable "assets_lifecycle_rules" {
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
  description = "Lifecycle rules for assets bucket"
  default     = []
}

variable "assets_cors_rules" {
  type = list(object({
    origin          = list(string)
    method          = list(string)
    response_header = optional(list(string))
    max_age_seconds = optional(number)
  }))
  description = "CORS rules for assets bucket"
  default     = []
}

variable "assets_iam_bindings" {
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  description = "IAM bindings for assets bucket"
  default     = []
}

# Logs bucket configuration
variable "logs_bucket_name" {
  type        = string
  description = "Name for the logs bucket"
}

variable "logs_bucket_location" {
  type        = string
  description = "Location for the logs bucket"
  default     = "US-CENTRAL1"
}

variable "logs_bucket_storage_class" {
  type        = string
  description = "Storage class for the logs bucket"
  default     = "COLDLINE"
}

variable "logs_bucket_labels" {
  type        = map(string)
  description = "Labels for the logs bucket"
  default     = {}
}

variable "logs_lifecycle_rules" {
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
  description = "Lifecycle rules for logs bucket"
  default     = []
}

variable "logs_retention_policy_days" {
  type        = number
  description = "Retention policy in days for logs bucket"
  default     = 0
}

variable "logs_retention_policy_locked" {
  type        = bool
  description = "Whether logs retention policy is locked"
  default     = false
}

variable "logs_iam_bindings" {
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  description = "IAM bindings for logs bucket"
  default     = []
}

# Backups bucket configuration
variable "backups_bucket_name" {
  type        = string
  description = "Name for the backups bucket"
}

variable "backups_bucket_location" {
  type        = string
  description = "Location for the backups bucket"
  default     = "US"
}

variable "backups_bucket_storage_class" {
  type        = string
  description = "Storage class for the backups bucket"
  default     = "ARCHIVE"
}

variable "backups_bucket_labels" {
  type        = map(string)
  description = "Labels for the backups bucket"
  default     = {}
}

variable "backups_enable_versioning" {
  type        = bool
  description = "Enable versioning for backups bucket"
  default     = true
}

variable "backups_lifecycle_rules" {
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
  description = "Lifecycle rules for backups bucket"
  default     = []
}

variable "backups_retention_policy_days" {
  type        = number
  description = "Retention policy in days for backups bucket"
  default     = 0
}

variable "backups_retention_policy_locked" {
  type        = bool
  description = "Whether backups retention policy is locked"
  default     = false
}

variable "backups_iam_bindings" {
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  description = "IAM bindings for backups bucket"
  default     = []
}