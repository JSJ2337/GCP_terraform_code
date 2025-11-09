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
