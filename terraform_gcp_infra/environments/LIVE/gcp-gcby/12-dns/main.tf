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

# Naming 모듈로 일관된 이름 생성
module "naming" {
  source = "../../../../modules/naming"

  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

# 공통 라벨
locals {
  common_labels = merge(
    module.naming.common_labels,
    var.labels
  )

  # DNS Zone 이름 (zone_name이 비어있으면 naming 모듈 기반으로 생성)
  zone_name = length(trimspace(var.zone_name)) > 0 ? var.zone_name : "${var.project_name}-${var.environment}-zone"
}

# Cloud DNS Managed Zone
module "cloud_dns" {
  source = "../../../../modules/cloud-dns"

  project_id  = var.project_id
  zone_name   = local.zone_name
  dns_name    = var.dns_name
  description = var.description

  visibility       = var.visibility
  private_networks = var.private_networks

  enable_dnssec     = var.enable_dnssec
  dnssec_key_specs  = var.dnssec_key_specs

  target_name_servers = var.target_name_servers
  peering_network     = var.peering_network

  labels = local.common_labels

  dns_records = var.dns_records

  # DNS Policy
  create_dns_policy         = var.create_dns_policy
  dns_policy_name           = var.dns_policy_name
  dns_policy_description    = var.dns_policy_description
  enable_inbound_forwarding = var.enable_inbound_forwarding
  enable_dns_logging        = var.enable_dns_logging
  alternative_name_servers  = var.alternative_name_servers
  dns_policy_networks       = var.dns_policy_networks
}
