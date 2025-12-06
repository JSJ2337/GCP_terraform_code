# =============================================================================
# 66-psc-endpoints - PSC Forwarding Rules for Cloud SQL and Redis
# =============================================================================
# 이 레이어는 60-database와 65-cache 배포 후 실행됩니다.
# Service Attachment를 참조하여 PSC endpoint를 생성합니다.
# =============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}

# Naming module for consistent resource naming
module "naming" {
  source = "../../../../modules/naming"

  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
  base_labels    = var.base_labels
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  # PSC subnet self_link
  psc_subnet_self_link = "projects/${var.project_id}/regions/${var.region_primary}/subnetworks/${var.psc_subnet_name}"

  # VPC self_link
  vpc_self_link = "projects/${var.project_id}/global/networks/${var.vpc_name}"
}

# -----------------------------------------------------------------------------
# PSC Forwarding Rule for Cloud SQL
# -----------------------------------------------------------------------------
resource "google_compute_address" "cloudsql_psc" {
  count = var.cloudsql_service_attachment != "" ? 1 : 0

  project      = var.project_id
  name         = "${var.project_name}-${var.environment}-gdb-m1-psc"
  region       = var.region_primary
  subnetwork   = local.psc_subnet_self_link
  address_type = "INTERNAL"
  address      = var.psc_cloudsql_ip
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "cloudsql_psc" {
  count = var.cloudsql_service_attachment != "" ? 1 : 0

  project               = var.project_id
  name                  = "${var.project_name}-${var.environment}-gdb-m1-psc-fr"
  region                = var.region_primary
  network               = local.vpc_self_link
  ip_address            = google_compute_address.cloudsql_psc[0].id
  load_balancing_scheme = ""
  target                = var.cloudsql_service_attachment

  # Cross-region access
  allow_psc_global_access = true
}

# -----------------------------------------------------------------------------
# PSC Forwarding Rules for Redis
# Redis Cluster는 2개의 Service Attachment (Discovery + Shard)
# -----------------------------------------------------------------------------
resource "google_compute_address" "redis_psc" {
  count = length(var.redis_service_attachments)

  project      = var.project_id
  name         = "${var.project_name}-${var.environment}-redis-psc-${count.index}"
  region       = var.region_primary
  subnetwork   = local.psc_subnet_self_link
  address_type = "INTERNAL"
  address      = var.psc_redis_ips[count.index]
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "redis_psc" {
  count = length(var.redis_service_attachments)

  project               = var.project_id
  name                  = "${var.project_name}-${var.environment}-redis-psc-fr-${count.index}"
  region                = var.region_primary
  network               = local.vpc_self_link
  ip_address            = google_compute_address.redis_psc[count.index].id
  load_balancing_scheme = ""
  target                = var.redis_service_attachments[count.index]

  # Cross-region access
  allow_psc_global_access = true
}
