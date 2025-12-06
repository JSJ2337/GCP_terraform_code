terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

}

provider "google" {
  project               = var.project_id
  region                = var.region_primary
  user_project_override = true
  billing_project       = var.project_id
}

# =============================================================================
# Cross-Project PSC Connections는 66-psc-endpoints 레이어로 분리됨
# GCP Best Practice: Redis Cluster 생성과 PSC 연결 등록을 분리
# =============================================================================

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

locals {
  # Memorystore requires a ZONE for location_id; use default_zone when region is not explicitly set
  region_effective = length(trimspace(var.region)) > 0 ? trimspace(var.region) : module.naming.default_zone
  region_base = (
    length(local.region_effective) > 2
    ? substr(local.region_effective, 0, length(local.region_effective) - 2)
    : local.region_effective
  )
  instance_name      = length(trimspace(var.instance_name)) > 0 ? var.instance_name : module.naming.redis_instance_name
  authorized_network = length(trimspace(var.authorized_network)) > 0 ? var.authorized_network : "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"
  labels             = merge(module.naming.common_labels, var.labels)
  alternative_location = (
    length(trimspace(var.alternative_location_id)) > 0
    ? trimspace(var.alternative_location_id)
    : (
      length(trimspace(var.alternative_location_suffix)) > 0
      ? "${local.region_base}-${trimspace(var.alternative_location_suffix)}"
      : ""
    )
  )
}

module "cache" {
  source = "../../../../modules/memorystore-redis"

  project_id                      = var.project_id
  instance_name                   = local.instance_name
  region                          = local.region_effective
  alternative_location_id         = local.alternative_location
  tier                            = var.tier
  replica_count                   = var.replica_count
  shard_count                     = var.shard_count
  memory_size_gb                  = var.memory_size_gb
  redis_version                   = var.redis_version
  authorized_network              = local.authorized_network
  connect_mode                    = var.connect_mode
  transit_encryption_mode         = var.transit_encryption_mode
  display_name                    = var.display_name
  labels                          = local.labels
  maintenance_window_day          = var.maintenance_window_day
  maintenance_window_start_hour   = var.maintenance_window_start_hour
  maintenance_window_start_minute = var.maintenance_window_start_minute

  # Cross-project PSC 연결은 66-psc-endpoints에서 처리
  cross_project_psc_connections = []
}
