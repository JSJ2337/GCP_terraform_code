terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

# Common naming conventions
locals {
  environment    = "prod"
  project_name   = "game-a"
  project_prefix = "${local.environment}-${local.project_name}"

  # Default VPC name following naming convention
  default_vpc_name = "${local.project_prefix}-vpc"
}

module "net" {
  source = "../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = var.vpc_name != "" ? var.vpc_name : local.default_vpc_name
  routing_mode = var.routing_mode

  subnets = var.subnets

  nat_region           = var.nat_region
  nat_min_ports_per_vm = var.nat_min_ports_per_vm

  firewall_rules = var.firewall_rules
}
