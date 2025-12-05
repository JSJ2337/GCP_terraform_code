variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = ""
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "organization" {
  type    = string
  default = "myorg"
}

variable "region_primary" {
  type    = string
  default = "us-central1"
}

variable "region_backup" {
  type    = string
  default = "us-east1"
}

variable "region" {
  type        = string
  description = "Default GCP region for resources"
  default     = "us-central1"
}

variable "folder_id" {
  type        = string
  default     = null
  description = "Optional: set when not using dynamic folders via bootstrap state"
}

variable "org_id" {
  type    = string
  default = null
}

## Dynamic folder selection via bootstrap remote state
variable "folder_product" {
  type        = string
  default     = "games"
  description = "Bootstrap folder product key (e.g., games, games2)"
}

variable "folder_region" {
  type        = string
  default     = "kr-region"
  description = "Bootstrap folder region key (e.g., kr-region, us-region)"
}

variable "folder_env" {
  type        = string
  default     = "LIVE"
  description = "Bootstrap folder environment key (LIVE/Staging/GQ-dev)"
}

variable "bootstrap_state_bucket" {
  type        = string
  description = "GCS bucket storing bootstrap state (root.hcl에서 자동 전달)"
}

variable "bootstrap_state_prefix" {
  type        = string
  default     = "bootstrap"
  description = "GCS prefix for bootstrap state (root.hcl에서 자동 전달)"
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
    "cloudkms.googleapis.com"
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
  description = "Cloud Logging 기본 버킷(_Default) 보존기간 설정을 관리할지 여부"
  type        = bool
  default     = true
}

variable "logging_api_wait_duration" {
  description = "logging.googleapis.com 활성화 후 대기 시간 (예: \"60s\")"
  type        = string
  default     = "60s"
}

variable "cmek_key_id" {
  type    = string
  default = ""
}
