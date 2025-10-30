variable "project_id" { type = string }

variable "region" {
  type        = string
  description = "Default GCP region for resources"
  default     = "us-central1"
}

variable "enable_central_log_sink" {
  type    = bool
  default = false
}

variable "central_logging_project" {
  type    = string
  default = ""
}

variable "central_logging_bucket" {
  type    = string
  default = "_Default"
}

variable "log_filter" {
  type    = string
  default = ""
}

variable "dashboard_json_files" {
  type    = list(string)
  default = []
}
