variable "project_id" {

variable "region" {
  type        = string
  description = "Default GCP region for resources"
  default     = "us-central1"
}
  type = string
}

variable "project_name" {
  type    = string
  default = ""
}

variable "folder_id" {
  type = string
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
