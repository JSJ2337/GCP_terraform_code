output "zone_name" {
  description = "생성된 Managed Zone의 이름"
  value       = google_dns_managed_zone.zone.name
}

output "zone_id" {
  description = "생성된 Managed Zone의 ID"
  value       = google_dns_managed_zone.zone.id
}

output "dns_name" {
  description = "Managed Zone의 DNS 도메인 이름"
  value       = google_dns_managed_zone.zone.dns_name
}

output "name_servers" {
  description = "Managed Zone의 네임서버 목록 (Public Zone에서만 제공)"
  value       = google_dns_managed_zone.zone.name_servers
}

output "visibility" {
  description = "Managed Zone의 가시성 (public/private)"
  value       = google_dns_managed_zone.zone.visibility
}

output "managed_zone_id" {
  description = "Managed Zone의 GCP 리소스 ID"
  value       = google_dns_managed_zone.zone.managed_zone_id
}

output "dns_records" {
  description = "생성된 DNS 레코드 정보"
  value = {
    for k, v in google_dns_record_set.records : k => {
      name    = v.name
      type    = v.type
      ttl     = v.ttl
      rrdatas = v.rrdatas
    }
  }
}

output "dns_policy_id" {
  description = "생성된 DNS Policy ID (생성된 경우)"
  value       = try(google_dns_policy.policy[0].id, null)
}

output "dns_policy_name" {
  description = "생성된 DNS Policy 이름 (생성된 경우)"
  value       = try(google_dns_policy.policy[0].name, null)
}
