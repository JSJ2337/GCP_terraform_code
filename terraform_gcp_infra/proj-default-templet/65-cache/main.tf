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
# Remote State for Cross-Project PSC Connections
# =============================================================================
# bootstrap/10-network에서 생성된 PSC Forwarding Rule 정보를 읽어옴
data "terraform_remote_state" "bootstrap_network" {
  count   = var.enable_cross_project_psc ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "bootstrap/10-network"
  }
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

  # Bootstrap에서 생성된 Redis PSC Forwarding Rules 정보
  mgmt_redis_forwarding_rules = var.enable_cross_project_psc ? try(
    data.terraform_remote_state.bootstrap_network[0].outputs.psc_redis_forwarding_rules, []
  ) : []
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

  # Cross-project PSC 연결 (mgmt VPC에서 접근 허용)
  # google_redis_cluster_user_created_connections 리소스를 통해 등록됨
  cross_project_psc_connections = var.enable_cross_project_psc && length(local.mgmt_redis_forwarding_rules) > 0 ? [
    {
      project_id = var.mgmt_project_id
      network    = var.mgmt_vpc_network
      forwarding_rules = [
        for fr in local.mgmt_redis_forwarding_rules : {
          psc_connection_id = fr.psc_connection_id
          forwarding_rule   = fr.forwarding_rule  # Full URL: projects/{project}/regions/{region}/forwardingRules/{name}
          ip_address        = fr.ip_address
        }
      ]
    }
  ] : []
}
