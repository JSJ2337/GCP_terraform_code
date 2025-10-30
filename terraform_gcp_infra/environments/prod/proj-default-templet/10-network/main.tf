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
  region  = "us-central1"
}

# Naming conventions imported from parent locals.tf
# All resource names are defined in ../locals.tf

module "net" {
  source = "../../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = local.vpc_name # Use naming from locals.tf
  routing_mode = var.routing_mode

  # Construct subnets map using locals for names
  subnets = {
    (local.subnet_name_primary) = {
      region                = local.region_primary
      cidr                  = var.subnet_primary_cidr
      private_google_access = true
      secondary_ranges = [
        {
          name = local.pods_range_name
          cidr = var.pods_cidr
        },
        {
          name = local.services_range_name
          cidr = var.services_cidr
        }
      ]
    }
    (local.subnet_name_backup) = {
      region                = local.region_backup
      cidr                  = var.subnet_backup_cidr
      private_google_access = true
      secondary_ranges      = []
    }
  }

  nat_region           = local.region_primary
  nat_min_ports_per_vm = var.nat_min_ports_per_vm

  firewall_rules = var.firewall_rules
}
