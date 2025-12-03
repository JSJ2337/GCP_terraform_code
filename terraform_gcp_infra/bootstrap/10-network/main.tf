# =============================================================================
# 10-network: 관리용 네트워크 인프라 (VPC, Subnet, Router, NAT)
# Firewall 규칙은 15-firewall 레이어로 분리됨
# =============================================================================

locals {
  network_name = "${var.management_project_id}-vpc"
  subnet_name  = "${var.management_project_id}-subnet"

  # PSC Endpoints는 terragrunt.hcl에서 동적으로 생성되어 전달됨
  # (projects 구조를 순회하며 자동 생성)
  psc_endpoints = var.psc_endpoints

  # VPC Peering 대상 목록도 terragrunt.hcl에서 전달됨
  # 형식: { project_key = "projects/{id}/global/networks/{name}" }
  project_vpc_peerings = var.project_vpc_network_urls
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
# 동적으로 모든 프로젝트 VPC와 Peering 생성
# 새 프로젝트 추가 시: bootstrap/common.hcl의 projects에 추가하면 자동 반영
resource "google_compute_network_peering" "mgmt_to_projects" {
  for_each = local.project_vpc_peerings

  name         = "peering-mgmt-to-${each.key}"
  network      = google_compute_network.mgmt_vpc.self_link
  peer_network = each.value

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

