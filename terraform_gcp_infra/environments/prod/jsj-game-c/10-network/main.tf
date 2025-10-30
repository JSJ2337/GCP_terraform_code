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
# local.vpc_name is already defined in parent

module "net" {
  source = "../../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = var.vpc_name != "" ? var.vpc_name : local.vpc_name
  routing_mode = var.routing_mode

  subnets = var.subnets

  nat_region           = var.nat_region
  nat_min_ports_per_vm = var.nat_min_ports_per_vm

  firewall_rules = var.firewall_rules
}
