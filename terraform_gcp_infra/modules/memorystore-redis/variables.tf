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
  validation {
    condition = contains([
      "BASIC",
      "STANDARD_HA",
      "ENTERPRISE",
      "ENTERPRISE_PLUS"
    ], var.tier)
    error_message = "tier must be one of BASIC, STANDARD_HA, ENTERPRISE, ENTERPRISE_PLUS."
  }
}

variable "replica_count" {
  type        = number
  description = "Number of read replicas for Enterprise tiers (>= 1 enables read endpoint)"
  default     = null
  validation {
    condition     = var.replica_count == null || var.replica_count >= 1
    error_message = "replica_count must be null or a value greater than or equal to 1."
  }
}

variable "shard_count" {
  type        = number
  description = "Number of shards for Enterprise tiers (set to >= 1 when using Sharded Enterprise)"
  default     = null
  validation {
    condition     = var.shard_count == null || var.shard_count >= 1
    error_message = "shard_count must be null or a value greater than or equal to 1."
  }
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
  description = "Desired Redis version (REDIS_3_2, REDIS_4_0, REDIS_5_0, REDIS_6_X)"
  default     = "REDIS_6_X"

  validation {
    condition = contains([
      "REDIS_3_2",
      "REDIS_4_0",
      "REDIS_5_0",
      "REDIS_6_X"
    ], var.redis_version)
    error_message = "redis_version must be one of REDIS_3_2, REDIS_4_0, REDIS_5_0, REDIS_6_X (REDIS_7_X is not yet supported by the Google provider)."
  }
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

variable "enterprise_node_type" {
  type        = string
  description = "Node type for Enterprise tiers (e.g., REDIS_STANDARD_SMALL, REDIS_HIGHMEM_MEDIUM)"
  default     = "REDIS_STANDARD_SMALL"
}

variable "enterprise_authorization_mode" {
  type        = string
  description = "Authorization mode for Enterprise tiers (AUTH_MODE_IAM_AUTH, AUTH_MODE_DISABLED)"
  default     = "AUTH_MODE_DISABLED"
}

variable "enterprise_transit_encryption_mode" {
  type        = string
  description = "Transit encryption mode for Enterprise tiers (TRANSIT_ENCRYPTION_MODE_DISABLED or TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION)"
  default     = "TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"
}

variable "enterprise_redis_configs" {
  type        = map(string)
  description = "Optional Redis configuration map applied to Enterprise clusters"
  default     = {}
}
