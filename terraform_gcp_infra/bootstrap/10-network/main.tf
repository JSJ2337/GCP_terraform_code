# =============================================================================
# 10-network: 관리용 네트워크 인프라 (VPC, Subnet, Router, NAT)
# Firewall 규칙은 15-firewall 레이어로 분리됨
# =============================================================================

locals {
  network_name = "${var.management_project_id}-vpc"
  subnet_name  = "${var.management_project_id}-subnet"
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
# 2) Subnet
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 3) Cloud Router (NAT용)
# -----------------------------------------------------------------------------
resource "google_compute_router" "mgmt_router" {
  project = var.management_project_id
  name    = "${var.management_project_id}-router"
  region  = var.region_primary
  network = google_compute_network.mgmt_vpc.id

  bgp {
    asn = 64514
  }
}

# -----------------------------------------------------------------------------
# 4) Cloud NAT
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 5) VPC Peering to project VPCs (for DNS resolution and private connectivity)
# -----------------------------------------------------------------------------
# Peering to gcp-gcby project
resource "google_compute_network_peering" "mgmt_to_gcby" {
  name         = "peering-mgmt-to-gcby"
  network      = google_compute_network.mgmt_vpc.self_link
  peer_network = "projects/gcp-gcby/global/networks/gcby-live-vpc"

  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network.mgmt_vpc]
}

