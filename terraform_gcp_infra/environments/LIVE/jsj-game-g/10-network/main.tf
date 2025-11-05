terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

  backend "gcs" {}
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

module "net" {
  source = "../../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = module.naming.vpc_name
  routing_mode = var.routing_mode

  # Construct subnets map using modules/naming outputs for names
  subnets = {
    (module.naming.subnet_name_primary) = {
      region                = module.naming.region_primary
      cidr                  = var.subnet_primary_cidr
      private_google_access = true
      secondary_ranges = [
        {
          name = module.naming.pods_range_name
          cidr = var.pods_cidr
        },
        {
          name = module.naming.services_range_name
          cidr = var.services_cidr
        }
      ]
    }
    (module.naming.subnet_name_backup) = {
      region                = module.naming.region_backup
      cidr                  = var.subnet_backup_cidr
      private_google_access = true
      secondary_ranges      = []
    }
  }

  nat_region           = module.naming.region_primary
  nat_min_ports_per_vm = var.nat_min_ports_per_vm

  firewall_rules = var.firewall_rules
}

locals {
  private_service_connection_name = length(trimspace(var.private_service_connection_name)) > 0 ? var.private_service_connection_name : "${module.naming.vpc_name}-psc"
}

resource "google_compute_global_address" "private_service_connect" {
  count        = var.enable_private_service_connection ? 1 : 0
  name         = local.private_service_connection_name
  project      = var.project_id
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"

  prefix_length = var.private_service_connection_prefix_length
  network       = module.net.vpc_self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.enable_private_service_connection ? 1 : 0
  network                 = module.net.vpc_self_link
  service                 = "services/servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect[0].name]

  depends_on = [google_compute_global_address.private_service_connect]
}
