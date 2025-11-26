variable "project_id" {
  type = string
}

variable "project_name" {
  type        = string
  description = "Project name used for naming"
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "live"
}

variable "organization" {
  type        = string
  description = "Organization prefix"
  default     = "myorg"
}

variable "region_primary" {
  type        = string
  description = "Primary region"
  default     = "us-central1"
}

variable "region_backup" {
  type        = string
  description = "Backup region"
  default     = "us-east1"
}

variable "region" {
  type        = string
  description = "Default GCP region for resources"
  default     = "us-central1"
}

variable "bindings" {
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "create_service_accounts" {
  type    = bool
  default = false
}

variable "service_accounts" {
  type = list(object({
    account_id   = string
    display_name = optional(string)
    description  = optional(string)
  }))
  default = []
}
