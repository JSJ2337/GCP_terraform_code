variable "project_name" {
  type        = string
  description = "Base project name used for naming conventions (e.g., default-templet)"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g., prod, stg, dev)"
}

variable "organization" {
  type        = string
  description = "Organization or business unit prefix (used in resource names)"
}

variable "region_primary" {
  type        = string
  description = "Primary region for regional resources (e.g., us-central1)"
}

variable "region_backup" {
  type        = string
  description = "Backup region for failover resources (e.g., us-east1)"
}

variable "default_zone_suffix" {
  type        = string
  description = "Suffix appended to the primary region to build a default zone"
  default     = "a"
}

variable "base_labels" {
  type        = map(string)
  description = "Base label map merged into common_labels before environment/project keys are added"
  default = {
    "managed-by"  = "terraform"
    "cost-center" = "it-infra-deps"
    "created-by"  = "system-team"
    "compliance"  = "none"
  }
}

variable "extra_tags" {
  type        = list(string)
  description = "Additional tags appended to the default [environment, project_name] set"
  default     = []
}
