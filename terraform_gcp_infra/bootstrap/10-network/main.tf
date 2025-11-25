# =============================================================================
# 10-network: 관리용 네트워크 인프라 (VPC, Subnet, Firewall, NAT)
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
# 5) Firewall Rules
# -----------------------------------------------------------------------------

# SSH 허용 (IAP 터널링용)
resource "google_compute_firewall" "allow_iap_ssh" {
  project     = var.management_project_id
  name        = "${local.network_name}-allow-iap-ssh"
  network     = google_compute_network.mgmt_vpc.id
  description = "Allow SSH from IAP"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP 터널링 IP 대역
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-ssh"]

  # Firewall 로그 활성화
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Jenkins 웹 UI 허용
resource "google_compute_firewall" "allow_jenkins" {
  project     = var.management_project_id
  name        = "${local.network_name}-allow-jenkins"
  network     = google_compute_network.mgmt_vpc.id
  description = "Allow Jenkins Web UI"

  allow {
    protocol = "tcp"
    ports    = ["8080", "443"]
  }

  source_ranges = var.jenkins_allowed_cidrs
  target_tags   = ["jenkins"]

  # Firewall 로그 활성화 (인터넷 facing 규칙)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Bastion SSH 허용 (외부에서 직접 접속)
resource "google_compute_firewall" "allow_bastion_ssh" {
  project     = var.management_project_id
  name        = "${local.network_name}-allow-bastion-ssh"
  network     = google_compute_network.mgmt_vpc.id
  description = "Allow SSH to Bastion from external"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.bastion_allowed_cidrs
  target_tags   = ["bastion"]

  # Firewall 로그 활성화 (인터넷 facing 규칙)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 내부 통신 허용
resource "google_compute_firewall" "allow_internal" {
  project     = var.management_project_id
  name        = "${local.network_name}-allow-internal"
  network     = google_compute_network.mgmt_vpc.id
  description = "Allow internal communication"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["allow-internal"]
}
