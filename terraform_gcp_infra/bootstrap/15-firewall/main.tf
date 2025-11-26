# =============================================================================
# 15-firewall: 관리용 네트워크 방화벽 규칙
# =============================================================================

# -----------------------------------------------------------------------------
# 1) IAP SSH 허용
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_iap_ssh" {
  project     = var.management_project_id
  name        = "${var.vpc_name}-allow-iap-ssh"
  network     = var.vpc_self_link
  description = "Allow SSH from IAP"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP 터널링 IP 대역
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-iap"]

  # Firewall 로그 활성화
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# 2) Jenkins 웹 UI 허용
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_jenkins" {
  project     = var.management_project_id
  name        = "${var.vpc_name}-allow-jenkins"
  network     = var.vpc_self_link
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

# -----------------------------------------------------------------------------
# 3) Bastion SSH 허용 (외부에서 직접 접속)
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_bastion_ssh" {
  project     = var.management_project_id
  name        = "${var.vpc_name}-allow-bastion-ssh"
  network     = var.vpc_self_link
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

# -----------------------------------------------------------------------------
# 4) 내부 통신 허용
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  project     = var.management_project_id
  name        = "${var.vpc_name}-allow-internal"
  network     = var.vpc_self_link
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
