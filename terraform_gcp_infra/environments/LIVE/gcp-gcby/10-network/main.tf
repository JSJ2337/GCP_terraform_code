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
  subnet_types = ["dmz", "private"]

  normalized_subnets = [
    for idx, subnet in var.additional_subnets :
    merge(
      subnet,
      {
        name = coalesce(
          lookup(subnet, "name", null),
          try("${var.project_name}-subnet-${local.subnet_types[idx]}", "subnet-${idx}")
        )
        region = coalesce(
          lookup(subnet, "region", null),
          var.region_primary
        )
      }
    )
  ]

  requested_subnets = {
    for subnet in local.normalized_subnets :
    subnet.name => {
      region                = subnet.region
      cidr                  = subnet.cidr
      private_google_access = lookup(subnet, "private_google_access", true)
      secondary_ranges      = lookup(subnet, "secondary_ranges", [])
    }
  }

  default_dmz_subnet_name     = try(local.normalized_subnets[0].name, "")
  default_private_subnet_name = try(local.normalized_subnets[1].name, "")
  default_db_subnet_name      = try(local.normalized_subnets[2].name, "")

  dmz_subnet_name     = length(trimspace(var.dmz_subnet_name)) > 0 ? var.dmz_subnet_name : local.default_dmz_subnet_name
  private_subnet_name = length(trimspace(var.private_subnet_name)) > 0 ? var.private_subnet_name : local.default_private_subnet_name
  db_subnet_name      = length(trimspace(var.db_subnet_name)) > 0 ? var.db_subnet_name : local.default_db_subnet_name

  dmz_subnet     = try(local.requested_subnets[local.dmz_subnet_name], null)
  private_subnet = try(local.requested_subnets[local.private_subnet_name], null)
  db_subnet      = try(local.requested_subnets[local.db_subnet_name], null)

  dmz_subnet_self_link     = local.dmz_subnet != null ? "projects/${var.project_id}/regions/${local.dmz_subnet.region}/subnetworks/${local.dmz_subnet_name}" : null
  private_subnet_self_link = local.private_subnet != null ? "projects/${var.project_id}/regions/${local.private_subnet.region}/subnetworks/${local.private_subnet_name}" : null
  db_subnet_self_link      = local.db_subnet != null ? "projects/${var.project_id}/regions/${local.db_subnet.region}/subnetworks/${local.db_subnet_name}" : null

  memorystore_psc_subnet_name      = length(trimspace(var.memorystore_psc_subnet_name)) > 0 ? var.memorystore_psc_subnet_name : local.private_subnet_name
  memorystore_psc_subnet           = try(local.requested_subnets[local.memorystore_psc_subnet_name], null)
  memorystore_psc_subnet_self_link = local.memorystore_psc_subnet != null ? "projects/${var.project_id}/regions/${local.memorystore_psc_subnet.region}/subnetworks/${local.memorystore_psc_subnet_name}" : ""
  memorystore_psc_region           = length(trimspace(var.memorystore_psc_region)) > 0 ? var.memorystore_psc_region : module.naming.region_primary
  memorystore_psc_policy_name      = length(trimspace(var.memorystore_psc_policy_name)) > 0 ? var.memorystore_psc_policy_name : "${module.naming.vpc_name}-${local.memorystore_psc_region}-redis-psc"

  cloudsql_psc_subnet_name      = length(trimspace(var.cloudsql_psc_subnet_name)) > 0 ? var.cloudsql_psc_subnet_name : local.private_subnet_name
  cloudsql_psc_subnet           = try(local.requested_subnets[local.cloudsql_psc_subnet_name], null)
  cloudsql_psc_subnet_self_link = local.cloudsql_psc_subnet != null ? "projects/${var.project_id}/regions/${local.cloudsql_psc_subnet.region}/subnetworks/${local.cloudsql_psc_subnet_name}" : ""
  cloudsql_psc_region           = length(trimspace(var.cloudsql_psc_region)) > 0 ? var.cloudsql_psc_region : module.naming.region_primary
  cloudsql_psc_policy_name      = length(trimspace(var.cloudsql_psc_policy_name)) > 0 ? var.cloudsql_psc_policy_name : "${module.naming.vpc_name}-${local.cloudsql_psc_region}-cloudsql-psc"
}

module "net" {
  source = "../../../../modules/network-dedicated-vpc"

  project_id   = var.project_id
  vpc_name     = module.naming.vpc_name
  routing_mode = var.routing_mode

  subnets = local.requested_subnets

  nat_region           = module.naming.region_primary
  nat_min_ports_per_vm = var.nat_min_ports_per_vm
  nat_subnet_self_links = compact([
    local.dmz_subnet_self_link,
    local.private_subnet_self_link
  ])

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

resource "google_project_service" "networkconnectivity" {
  project            = var.project_id
  service            = "networkconnectivity.googleapis.com"
  disable_on_destroy = false
  depends_on         = [time_sleep.wait_core_apis]
}

resource "time_sleep" "wait_networkconnectivity_api" {
  depends_on      = [google_project_service.networkconnectivity]
  create_duration = "60s"
}

resource "google_network_connectivity_service_connection_policy" "memorystore_psc" {
  count         = var.enable_memorystore_psc_policy ? 1 : 0
  project       = var.project_id
  location      = local.memorystore_psc_region
  name          = local.memorystore_psc_policy_name
  service_class = "gcp-memorystore-redis"
  network       = "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"

  psc_config {
    subnetworks = [local.memorystore_psc_subnet_self_link]
    limit       = var.memorystore_psc_connection_limit
  }

  depends_on = [
    module.net,
    time_sleep.wait_networkconnectivity_api
  ]

  lifecycle {
    precondition {
      condition     = local.memorystore_psc_subnet_self_link != ""
      error_message = "memorystore_psc_subnet_name must reference an existing subnet in additional_subnets."
    }
  }
}

# Cloud SQL Private Service Connect Policy
resource "google_network_connectivity_service_connection_policy" "cloudsql_psc" {
  count         = var.enable_cloudsql_psc_policy ? 1 : 0
  project       = var.project_id
  location      = local.cloudsql_psc_region
  name          = local.cloudsql_psc_policy_name
  service_class = "google-cloud-sql"
  network       = "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"

  psc_config {
    subnetworks = [local.cloudsql_psc_subnet_self_link]
    limit       = var.cloudsql_psc_connection_limit
  }

  depends_on = [
    module.net,
    time_sleep.wait_networkconnectivity_api
  ]

  lifecycle {
    precondition {
      condition     = local.cloudsql_psc_subnet_self_link != ""
      error_message = "cloudsql_psc_subnet_name must reference an existing subnet in additional_subnets."
    }
  }
}

# VPC Peering to mgmt VPC for DNS resolution
resource "google_compute_network_peering" "gcby_to_mgmt" {
  name         = "peering-gcby-to-mgmt"
  network      = module.net.vpc_self_link  # Implicit dependency
  peer_network = var.peer_network_url

  import_custom_routes = true
  export_custom_routes = true
}

# -----------------------------------------------------------------------------
# PSC Forwarding Rule for Cloud SQL (consumer VPC에서 생성)
# -----------------------------------------------------------------------------
resource "google_compute_address" "cloudsql_psc" {
  count = length(var.cloudsql_service_attachment) > 0 ? 1 : 0

  project      = var.project_id
  name         = "${var.project_name}-cloudsql-psc"
  region       = var.region_primary
  subnetwork   = "projects/${var.project_id}/regions/${var.region_primary}/subnetworks/${var.project_name}-subnet-psc"
  address_type = "INTERNAL"
  address      = var.psc_cloudsql_ip
  purpose      = "GCE_ENDPOINT"

  depends_on = [module.net]
}

resource "google_compute_forwarding_rule" "cloudsql_psc" {
  count = length(var.cloudsql_service_attachment) > 0 ? 1 : 0

  project               = var.project_id
  name                  = "${var.project_name}-cloudsql-psc-fr"
  region                = var.region_primary
  network               = module.net.vpc_self_link
  ip_address            = google_compute_address.cloudsql_psc[0].id
  load_balancing_scheme = ""
  target                = var.cloudsql_service_attachment

  # Cross-region access 활성화
  allow_psc_global_access = true

  depends_on = [module.net]
}

# -----------------------------------------------------------------------------
# PSC Forwarding Rule for Redis (consumer VPC에서 생성)
# -----------------------------------------------------------------------------
resource "google_compute_address" "redis_psc" {
  count = length(var.redis_service_attachment) > 0 ? 1 : 0

  project      = var.project_id
  name         = "${var.project_name}-redis-psc"
  region       = var.region_primary
  subnetwork   = "projects/${var.project_id}/regions/${var.region_primary}/subnetworks/${var.project_name}-subnet-psc"
  address_type = "INTERNAL"
  address      = var.psc_redis_ip
  purpose      = "GCE_ENDPOINT"

  depends_on = [module.net]
}

resource "google_compute_forwarding_rule" "redis_psc" {
  count = length(var.redis_service_attachment) > 0 ? 1 : 0

  project               = var.project_id
  name                  = "${var.project_name}-redis-psc-fr"
  region                = var.region_primary
  network               = module.net.vpc_self_link
  ip_address            = google_compute_address.redis_psc[0].id
  load_balancing_scheme = ""
  target                = var.redis_service_attachment

  # Cross-region access 활성화
  allow_psc_global_access = true

  depends_on = [module.net]
}
