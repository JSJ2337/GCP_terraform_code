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
# Remote State for Cross-Project PSC Connections
# -----------------------------------------------------------------------------
# bootstrap/10-network에서 생성된 mgmt VPC의 Redis PSC Forwarding Rule 정보를 읽어옴
data "terraform_remote_state" "bootstrap_network" {
  count   = var.enable_cross_project_psc ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "bootstrap/10-network"
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  # PSC subnet self_link
  psc_subnet_self_link = "projects/${var.project_id}/regions/${var.region_primary}/subnetworks/${var.psc_subnet_name}"

  # VPC self_link
  vpc_self_link = "projects/${var.project_id}/global/networks/${var.vpc_name}"

  # Bootstrap에서 생성된 mgmt Redis PSC Forwarding Rules 정보
  mgmt_redis_forwarding_rules = var.enable_cross_project_psc ? try(
    data.terraform_remote_state.bootstrap_network[0].outputs.psc_redis_forwarding_rules, []
  ) : []
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

# -----------------------------------------------------------------------------
# Cross-Project PSC Connections for Redis
# -----------------------------------------------------------------------------
# mgmt VPC에서 이 프로젝트의 Redis Cluster에 접근하려면
# mgmt VPC의 PSC Forwarding Rule을 이 클러스터에 등록해야 함
#
# 참고: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_cluster_user_created_connections
# -----------------------------------------------------------------------------
resource "google_redis_cluster_user_created_connections" "mgmt_access" {
  count = var.enable_cross_project_psc && length(var.redis_service_attachments) > 0 && length(local.mgmt_redis_forwarding_rules) > 0 ? 1 : 0

  name    = var.redis_cluster_name
  region  = var.region_primary
  project = var.project_id

  # mgmt VPC의 PSC 연결 등록
  cluster_endpoints {
    dynamic "connections" {
      for_each = local.mgmt_redis_forwarding_rules
      content {
        psc_connection {
          psc_connection_id  = connections.value.psc_connection_id
          address            = connections.value.ip_address
          forwarding_rule    = connections.value.forwarding_rule
          network            = var.mgmt_vpc_network
          project_id         = var.mgmt_project_id
          service_attachment = replace(connections.value.service_attachment, "https://www.googleapis.com/compute/v1/", "")
        }
      }
    }
  }

  depends_on = [google_compute_forwarding_rule.redis_psc]
}
