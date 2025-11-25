# =============================================================================
# 12-dns: Cloud DNS Private Zone (중앙 관리형)
# =============================================================================
# 이 레이어는 mgmt 프로젝트에서 중앙 관리되는 Private DNS를 구성합니다.
# 다른 프로젝트에서는 VPC Peering을 통해 DNS 쿼리를 포워딩할 수 있습니다.
# =============================================================================

# -----------------------------------------------------------------------------
# 1) Private DNS Zone
# -----------------------------------------------------------------------------
resource "google_dns_managed_zone" "private" {
  project     = var.management_project_id
  name        = var.dns_zone_name
  dns_name    = var.dns_domain
  description = "Private DNS zone for internal resources (${var.dns_domain})"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.vpc_self_link
    }
  }

  labels = var.labels
}

# -----------------------------------------------------------------------------
# 2) DNS Records - Jenkins
# -----------------------------------------------------------------------------
resource "google_dns_record_set" "jenkins" {
  project      = var.management_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "jenkins.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.jenkins_internal_ip]
}

# -----------------------------------------------------------------------------
# 3) DNS Records - Bastion
# -----------------------------------------------------------------------------
resource "google_dns_record_set" "bastion" {
  project      = var.management_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "bastion.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.bastion_internal_ip]
}

# -----------------------------------------------------------------------------
# 4) 추가 DNS Records (동적 생성)
# -----------------------------------------------------------------------------
resource "google_dns_record_set" "additional" {
  for_each = var.additional_dns_records

  project      = var.management_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "${each.key}.${var.dns_domain}"
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

# -----------------------------------------------------------------------------
# 5) DNS Peering Zone (다른 프로젝트 VPC에서 이 Zone으로 쿼리 포워딩)
# 나중에 다른 프로젝트 생성 시 해당 프로젝트에서 peering zone을 만들어야 함
# 여기서는 mgmt VPC가 authoritative zone을 호스팅
# -----------------------------------------------------------------------------
# DNS Peering은 대상 프로젝트에서 구성해야 합니다.
# 예시 (다른 프로젝트에서):
#
# resource "google_dns_managed_zone" "peering_to_mgmt" {
#   name        = "peering-to-mgmt-dns"
#   dns_name    = "delabsgames.internal."
#   visibility  = "private"
#
#   private_visibility_config {
#     networks {
#       network_url = google_compute_network.project_vpc.self_link
#     }
#   }
#
#   peering_config {
#     target_network {
#       network_url = "projects/delabs-gcp-mgmt/global/networks/delabs-gcp-mgmt-vpc"
#     }
#   }
# }
