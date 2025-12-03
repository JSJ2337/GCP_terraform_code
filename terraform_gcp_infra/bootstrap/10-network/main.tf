# =============================================================================
# 10-network: 관리용 네트워크 인프라 (VPC, Subnet, Router, NAT)
# Firewall 규칙은 15-firewall 레이어로 분리됨
# =============================================================================

locals {
  network_name = "${var.management_project_id}-vpc"
  subnet_name  = "${var.management_project_id}-subnet"

  # PSC Endpoints 동적 생성 (Service Attachment를 dependency에서 가져옴)
  psc_endpoints = merge(
    var.psc_endpoints,
    # Cloud SQL
    length(var.gcby_cloudsql_service_attachment) > 0 ? {
      gcby-cloudsql = {
        region                    = "us-west1"
        ip_address                = var.psc_cloudsql_ip
        target_service_attachment = var.gcby_cloudsql_service_attachment
        allow_global_access       = true
      }
    } : {},
    # Redis
    length(var.gcby_redis_service_attachment) > 0 ? {
      gcby-redis = {
        region                    = "us-west1"
        ip_address                = var.psc_redis_ip
        target_service_attachment = var.gcby_redis_service_attachment
        allow_global_access       = true
      }
    } : {}
  )
}

# -----------------------------------------------------------------------------
# 1) VPC 네트워크
# -----------------------------------------------------------------------------
resource "google_compute_network" "mgmt_vpc" {
  project                 = var.management_project_id
  name                    = local.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "Management VPC for Jenkins and shared services"
}

# -----------------------------------------------------------------------------
# 2) Subnets
# -----------------------------------------------------------------------------
# Primary subnet (asia-northeast3)
resource "google_compute_subnetwork" "mgmt_subnet" {
  project       = var.management_project_id
  name          = local.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region_primary
  network       = google_compute_network.mgmt_vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# us-west1 subnet (PSC Endpoint용)
resource "google_compute_subnetwork" "mgmt_subnet_us_west1" {
  project       = var.management_project_id
  name          = "${var.management_project_id}-subnet-us-west1"
  ip_cidr_range = var.subnet_cidr_us_west1
  region        = "us-west1"
  network       = google_compute_network.mgmt_vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# 3) Cloud Routers (NAT용, 리전별)
# -----------------------------------------------------------------------------
# Primary region (asia-northeast3) Router
resource "google_compute_router" "mgmt_router" {
  project = var.management_project_id
  name    = "${var.management_project_id}-router"
  region  = var.region_primary
  network = google_compute_network.mgmt_vpc.id

  bgp {
    asn = 64514
  }
}

# us-west1 Router
resource "google_compute_router" "mgmt_router_us_west1" {
  project = var.management_project_id
  name    = "${var.management_project_id}-router-us-west1"
  region  = "us-west1"
  network = google_compute_network.mgmt_vpc.id

  bgp {
    asn = 64515
  }
}

# -----------------------------------------------------------------------------
# 4) Cloud NATs (리전별)
# -----------------------------------------------------------------------------
# Primary region (asia-northeast3) NAT
resource "google_compute_router_nat" "mgmt_nat" {
  project = var.management_project_id
  name    = "${var.management_project_id}-nat"
  router  = google_compute_router.mgmt_router.name
  region  = var.region_primary

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"  # 모든 NAT 로그 수집 (트러블슈팅용)
  }
}

# us-west1 NAT
resource "google_compute_router_nat" "mgmt_nat_us_west1" {
  project = var.management_project_id
  name    = "${var.management_project_id}-nat-us-west1"
  router  = google_compute_router.mgmt_router_us_west1.name
  region  = "us-west1"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}

# -----------------------------------------------------------------------------
# 5) VPC Peering to project VPCs (for DNS resolution and private connectivity)
# -----------------------------------------------------------------------------
# Peering to gcp-gcby project
resource "google_compute_network_peering" "mgmt_to_gcby" {
  name         = "peering-mgmt-to-gcby"
  network      = google_compute_network.mgmt_vpc.self_link  # Implicit dependency
  peer_network = "projects/gcp-gcby/global/networks/gcby-live-vpc"

  import_custom_routes = true
  export_custom_routes = true
}

# -----------------------------------------------------------------------------
# 6) PSC Endpoints for Cloud SQL (mgmt VPC용)
# -----------------------------------------------------------------------------
# Internal IP 주소 예약
resource "google_compute_address" "psc_addresses" {
  for_each = local.psc_endpoints

  project      = var.management_project_id
  name         = "${each.key}-psc"
  region       = each.value.region
  subnetwork   = each.value.region == "us-west1" ? google_compute_subnetwork.mgmt_subnet_us_west1.id : google_compute_subnetwork.mgmt_subnet.id
  address_type = "INTERNAL"
  address      = each.value.ip_address
  purpose      = "GCE_ENDPOINT"
}

# PSC Forwarding Rule
resource "google_compute_forwarding_rule" "psc_endpoints" {
  for_each = local.psc_endpoints

  project               = var.management_project_id
  name                  = "${each.key}-psc-fr"
  region                = each.value.region
  network               = google_compute_network.mgmt_vpc.id
  ip_address            = google_compute_address.psc_addresses[each.key].id
  load_balancing_scheme = ""
  target                = each.value.target_service_attachment

  # Cross-region access 활성화 (Global Access)
  allow_psc_global_access = each.value.allow_global_access
}

