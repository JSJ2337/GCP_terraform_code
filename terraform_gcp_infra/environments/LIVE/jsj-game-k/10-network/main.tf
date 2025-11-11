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
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
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
  primary_secondary_ranges = concat(
    length(trimspace(var.pods_cidr)) > 0 ? [
      {
        name = module.naming.pods_range_name
        cidr = var.pods_cidr
      }
    ] : [],
    length(trimspace(var.services_cidr)) > 0 ? [
      {
        name = module.naming.services_range_name
        cidr = var.services_cidr
      }
    ] : []
  )

  base_subnets = {
    (module.naming.subnet_name_primary) = {
      region                = module.naming.region_primary
      cidr                  = var.subnet_primary_cidr
      private_google_access = true
      secondary_ranges      = local.primary_secondary_ranges
    }
    (module.naming.subnet_name_backup) = {
      region                = module.naming.region_backup
      cidr                  = var.subnet_backup_cidr
      private_google_access = true
      secondary_ranges      = []
    }
  }

  additional_subnets_map = {
    for subnet in var.additional_subnets :
    subnet.name => {
      region                = subnet.region
      cidr                  = subnet.cidr
      private_google_access = lookup(subnet, "private_google_access", true)
      secondary_ranges      = lookup(subnet, "secondary_ranges", [])
    }
  }

  dmz_subnet     = try(local.additional_subnets_map[var.dmz_subnet_name], null)
  private_subnet = try(local.additional_subnets_map[var.private_subnet_name], null)
  db_subnet      = try(local.additional_subnets_map[var.db_subnet_name], null)

  dmz_subnet_self_link     = local.dmz_subnet != null ? "projects/${var.project_id}/regions/${local.dmz_subnet.region}/subnetworks/${var.dmz_subnet_name}" : null
  private_subnet_self_link = local.private_subnet != null ? "projects/${var.project_id}/regions/${local.private_subnet.region}/subnetworks/${var.private_subnet_name}" : null
  db_subnet_self_link      = local.db_subnet != null ? "projects/${var.project_id}/regions/${local.db_subnet.region}/subnetworks/${var.db_subnet_name}" : null
}

module "net" {
  source = "../../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = module.naming.vpc_name
  routing_mode = var.routing_mode

  subnets = merge(local.base_subnets, local.additional_subnets_map)

  nat_region            = module.naming.region_primary
  nat_min_ports_per_vm  = var.nat_min_ports_per_vm
  nat_subnet_self_links = local.dmz_subnet_self_link != null ? [local.dmz_subnet_self_link] : []

  firewall_rules = var.firewall_rules

  # Ensure all required APIs are enabled and propagated
  depends_on = [time_sleep.wait_servicenetworking_api]
}

locals {
  private_service_connection_name = length(trimspace(var.private_service_connection_name)) > 0 ? var.private_service_connection_name : "${module.naming.vpc_name}-psc"
}

# 필수 API 명시적 활성화 (신규 프로젝트에서 단독 실행해도 안전)
resource "google_project_service" "crm" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "serviceusage" {
  project            = var.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "time_sleep" "wait_core_apis" {
  depends_on      = [google_project_service.crm, google_project_service.serviceusage]
  create_duration = "60s"
}

resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
  depends_on         = [time_sleep.wait_core_apis]
}

resource "time_sleep" "wait_servicenetworking_api" {
  depends_on      = [google_project_service.servicenetworking]
  create_duration = "90s"
}
