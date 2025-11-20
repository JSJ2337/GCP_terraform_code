output "zone_name" {
  description = "생성된 Managed Zone의 이름"
  value       = module.cloud_dns.zone_name
}

output "zone_id" {
  description = "생성된 Managed Zone의 ID"
  value       = module.cloud_dns.zone_id
}

output "dns_name" {
  description = "Managed Zone의 DNS 도메인 이름"
  value       = module.cloud_dns.dns_name
}

output "name_servers" {
  description = "Managed Zone의 네임서버 목록 (Public Zone에서만 제공)"
  value       = module.cloud_dns.name_servers
}

output "visibility" {
  description = "Managed Zone의 가시성 (public/private)"
  value       = module.cloud_dns.visibility
}

output "managed_zone_id" {
  description = "Managed Zone의 GCP 리소스 ID"
  value       = module.cloud_dns.managed_zone_id
}

output "dns_records" {
  description = "생성된 DNS 레코드 정보"
  value       = module.cloud_dns.dns_records
}

output "dns_policy_id" {
  description = "생성된 DNS Policy ID (생성된 경우)"
  value       = module.cloud_dns.dns_policy_id
}

output "dns_policy_name" {
  description = "생성된 DNS Policy 이름 (생성된 경우)"
  value       = module.cloud_dns.dns_policy_name
}
