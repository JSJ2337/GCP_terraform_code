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
  description = "Deprecated: 폴더 ID는 main.tf에서 bootstrap remote state로 자동 참조됨"
}

variable "org_id" {
  type    = string
  default = null
}

variable "folder_product" {
  type        = string
  default     = "games"
  description = "Bootstrap 폴더 구조에서 사용할 product 키 (예: games, games2)"
}

variable "folder_region" {
  type        = string
  default     = "kr-region"
  description = "Bootstrap 폴더 구조에서 사용할 region 키"
}

variable "folder_env" {
  type        = string
  default     = "LIVE"
  description = "Bootstrap 폴더 구조에서 사용할 환경 키 (LIVE/Staging/GQ-dev)"
}

variable "bootstrap_state_bucket" {
  type        = string
  default     = "jsj-terraform-state-prod"
  description = "Bootstrap state가 저장된 GCS 버킷"
}

variable "bootstrap_state_prefix" {
  type        = string
  default     = "bootstrap"
  description = "Bootstrap state가 저장된 GCS prefix (workspace별 default.tfstate)"
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

variable "cmek_key_id" {
  type    = string
  default = ""
}
