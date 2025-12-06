# =============================================================================
# Variables for 66-psc-endpoints
# =============================================================================

# -----------------------------------------------------------------------------
# Naming module variables
# -----------------------------------------------------------------------------
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (live, stg, dev)"
  type        = string
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = ""
}

variable "region_primary" {
  description = "Primary region"
  type        = string
}

variable "region_backup" {
  description = "Backup region"
  type        = string
  default     = ""
}

variable "base_labels" {
  description = "Base labels for resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network variables
# -----------------------------------------------------------------------------
variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "psc_subnet_name" {
  description = "PSC subnet name"
  type        = string
}

# -----------------------------------------------------------------------------
# PSC endpoint variables
# -----------------------------------------------------------------------------
variable "psc_cloudsql_ip" {
  description = "IP address for Cloud SQL PSC endpoint"
  type        = string
}

variable "psc_redis_ips" {
  description = "IP addresses for Redis PSC endpoints"
  type        = list(string)
  default     = []
}

variable "cloudsql_service_attachment" {
  description = "Cloud SQL service attachment URI"
  type        = string
  default     = ""
}

variable "redis_service_attachments" {
  description = "Redis service attachment URIs (Discovery + Shard)"
  type        = list(string)
  default     = []
}
