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
  default     = "prod"
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

variable "zone" {
  type    = string
  default = ""
}

variable "subnetwork_self_link" {
  type    = string
  default = ""
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 1
}

variable "name_prefix" {
  type        = string
  description = "Prefix for instance names"
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "Machine type for instances"
  default     = "e2-micro"
}

variable "enable_public_ip" {
  type        = bool
  description = "Whether to enable public IP for instances"
  default     = false
}

variable "enable_os_login" {
  type        = bool
  description = "Whether to enable OS Login"
  default     = true
}

variable "preemptible" {
  type        = bool
  description = "Whether instances should be preemptible"
  default     = false
}

variable "startup_script" {
  type        = string
  description = "Startup script for instances"
  default     = ""
}

variable "service_account_email" {
  type        = string
  description = "Service account email for instances"
  default     = ""
}

variable "service_account_scopes" {
  type        = list(string)
  description = "Scopes for the service account"
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "tags" {
  type        = list(string)
  description = "Network tags for instances"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Labels for instances"
  default     = {}
}

# 새로운 for_each 방식 (권장)
variable "instances" {
  type = map(object({
    hostname             = optional(string)
    zone                 = optional(string)
    machine_type         = optional(string)
    subnetwork_self_link = optional(string)
    enable_public_ip     = optional(bool)
    enable_os_login      = optional(bool)
    preemptible          = optional(bool)
    startup_script       = optional(string)
    metadata             = optional(map(string))
    tags                 = optional(list(string))
    labels               = optional(map(string))
  }))
  default     = {}
  description = "VM 인스턴스 맵 (키=인스턴스명, 값=설정). 비워두면 instance_count 방식 사용"
}
