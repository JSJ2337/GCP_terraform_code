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

  # Wait for initial API propagation after 00-project enables required services
  depends_on = [time_sleep.initial_wait_for_project_apis]
}

# Initial wait to absorb API propagation delays (Cloud Resource Manager/Service Usage/Service Networking)
resource "time_sleep" "initial_wait_for_project_apis" {
  create_duration = "120s"
}
