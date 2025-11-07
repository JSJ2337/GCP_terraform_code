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
  project = var.project_id
  region  = var.region
}

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

locals {
  region_effective   = length(trimspace(var.region)) > 0 ? trimspace(var.region) : module.naming.region_primary
  instance_name      = length(trimspace(var.instance_name)) > 0 ? var.instance_name : module.naming.redis_instance_name
  authorized_network = length(trimspace(var.authorized_network)) > 0 ? var.authorized_network : "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"
  labels             = merge(module.naming.common_labels, var.labels)
  alternative_location = (
    length(trimspace(var.alternative_location_id)) > 0
    ? trimspace(var.alternative_location_id)
    : (
      length(trimspace(var.alternative_location_suffix)) > 0
      ? "${local.region_effective}-${trimspace(var.alternative_location_suffix)}"
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
}
