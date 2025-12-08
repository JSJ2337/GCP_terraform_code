# =============================================================================
# Outputs for 66-psc-endpoints
# =============================================================================

output "cloudsql_psc_endpoint" {
  description = "Cloud SQL PSC endpoint details"
  value = length(google_compute_forwarding_rule.cloudsql_psc) > 0 ? {
    name       = google_compute_forwarding_rule.cloudsql_psc[0].name
    ip_address = google_compute_address.cloudsql_psc[0].address
    target     = google_compute_forwarding_rule.cloudsql_psc[0].target
  } : null
}

# Redis PSC는 65-cache에서 자동 생성됨 (sca-auto-addr-* 주소)
# 66-psc-endpoints에서는 Cross-project PSC 등록만 수행
output "cross_project_psc_registered" {
  description = "Cross-project PSC 연결 등록 여부"
  value       = length(google_redis_cluster_user_created_connections.mgmt_access) > 0
}
