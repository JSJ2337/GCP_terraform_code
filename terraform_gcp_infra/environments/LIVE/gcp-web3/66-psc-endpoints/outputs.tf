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

output "redis_psc_endpoints" {
  description = "Redis PSC endpoint details"
  value = [
    for i, fr in google_compute_forwarding_rule.redis_psc : {
      name       = fr.name
      ip_address = google_compute_address.redis_psc[i].address
      target     = fr.target
    }
  ]
}
