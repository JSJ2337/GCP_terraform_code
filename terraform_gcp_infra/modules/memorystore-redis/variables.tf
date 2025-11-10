variable "project_id" {
  type        = string
  description = "GCP project ID where the Redis instance will be created"
}

variable "instance_name" {
  type        = string
  description = "Memorystore Redis instance name (must be unique per project)"

  validation {
    condition     = length(trimspace(var.instance_name)) > 0
    error_message = "instance_name must not be empty."
  }
}

variable "region" {
  type        = string
  description = "Primary zone (location_id) for the Redis instance. Must be a ZONE, not a region (e.g., us-central1-a, not us-central1)"
}

variable "alternative_location_id" {
  type        = string
  description = "Secondary zone for STANDARD_HA tier (e.g., us-central1-b). Leave blank for tiers that do not require it."
  default     = ""
}

variable "tier" {
  type        = string
  description = "Redis tier (STANDARD_HA, BASIC, ENTERPRISE, ENTERPRISE_PLUS)"
  default     = "STANDARD_HA"
}

variable "memory_size_gb" {
  type        = number
  description = "Memory size in GB"
  default     = 1

  validation {
    condition     = var.memory_size_gb >= 1
    error_message = "memory_size_gb must be at least 1 GB."
  }
}

variable "redis_version" {
  type        = string
  description = "Desired Redis version (e.g., REDIS_7_X)"
  default     = "REDIS_7_X"
}

variable "authorized_network" {
  type        = string
  description = "VPC self link that can access the instance (e.g., projects/<p>/global/networks/<vpc-name>)"

  validation {
    condition     = length(trimspace(var.authorized_network)) > 0
    error_message = "authorized_network must be provided for STANDARD_HA tier."
  }
}

variable "connect_mode" {
  type        = string
  description = "Connection mode (DIRECT_PEERING or PRIVATE_SERVICE_CONNECT). STANDARD_HA supports only DIRECT_PEERING."
  default     = "DIRECT_PEERING"
}

variable "transit_encryption_mode" {
  type        = string
  description = "Transit encryption mode (DISABLED or SERVER_AUTHENTICATION). SERVER_AUTHENTICATION is only supported on Enterprise tiers."
  default     = "DISABLED"
}

variable "display_name" {
  type        = string
  description = "Friendly display name for the Redis instance"
  default     = ""
}

variable "labels" {
  type        = map(string)
  description = "Key/value labels applied to the Redis instance"
  default     = {}
}

variable "maintenance_window_day" {
  type        = string
  description = "Day of weekly maintenance window (e.g., MONDAY). Leave blank to accept Google defaults."
  default     = ""
}

variable "maintenance_window_start_hour" {
  type        = number
  description = "Hour (0-23) for maintenance window. Required if maintenance_window_day is set."
  default     = null
}

variable "maintenance_window_start_minute" {
  type        = number
  description = "Minute (0-59) for maintenance window. Required if maintenance_window_day is set."
  default     = null
}
