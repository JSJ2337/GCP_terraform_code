variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = ""
}

variable "folder_id" {
  type    = string
  default = null
}

variable "org_id" {
  type    = string
  default = null
}

variable "billing_account" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "apis" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudkms.googleapis.com",
  ]
}

variable "enable_budget" {
  type    = bool
  default = false
}

variable "budget_amount" {
  type    = number
  default = 100
}

variable "budget_currency" {
  type    = string
  default = "USD"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "manage_default_logging_bucket" {
  description = "Whether to manage the default Cloud Logging bucket (_Default). Disable for initial project bootstraps if API propagation causes failures."
  type        = bool
  default     = true
}

variable "logging_api_wait_duration" {
  description = "Duration to wait after enabling logging.googleapis.com before configuring the default logging bucket (e.g., \"60s\")"
  type        = string
  default     = "60s"
}

variable "cmek_key_id" {
  type    = string
  default = ""
}
