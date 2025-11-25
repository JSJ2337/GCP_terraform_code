# =============================================================================
# 12-dns Outputs
# =============================================================================

output "dns_zone_name" {
  description = "DNS Zone 리소스 이름"
  value       = google_dns_managed_zone.private.name
}

output "dns_zone_dns_name" {
  description = "DNS Zone 도메인 이름"
  value       = google_dns_managed_zone.private.dns_name
}

output "dns_zone_id" {
  description = "DNS Zone ID"
  value       = google_dns_managed_zone.private.id
}

output "name_servers" {
  description = "DNS Zone Name Servers"
  value       = google_dns_managed_zone.private.name_servers
}

output "jenkins_fqdn" {
  description = "Jenkins 내부 FQDN"
  value       = google_dns_record_set.jenkins.name
}

output "bastion_fqdn" {
  description = "Bastion 내부 FQDN"
  value       = google_dns_record_set.bastion.name
}

# DNS Peering 설정을 위한 정보 (다른 프로젝트에서 사용)
output "peering_info" {
  description = "다른 프로젝트에서 DNS Peering 설정 시 필요한 정보"
  value = {
    target_network_url = var.vpc_self_link
    dns_domain         = var.dns_domain
    zone_name          = google_dns_managed_zone.private.name
  }
}
