output "backend_service_id" {
  description = "백엔드 서비스 ID"
  value = var.lb_type == "http" || var.lb_type == "internal" ? (
    length(google_compute_backend_service.default) > 0 ? google_compute_backend_service.default[0].id : null
    ) : (
    length(google_compute_region_backend_service.internal) > 0 ? google_compute_region_backend_service.internal[0].id : null
  )
}

output "backend_service_self_link" {
  description = "백엔드 서비스 셀프 링크"
  value = var.lb_type == "http" || var.lb_type == "internal" ? (
    length(google_compute_backend_service.default) > 0 ? google_compute_backend_service.default[0].self_link : null
    ) : (
    length(google_compute_region_backend_service.internal) > 0 ? google_compute_region_backend_service.internal[0].self_link : null
  )
}

output "health_check_id" {
  description = "헬스 체크 ID"
  value = length(google_compute_health_check.default) > 0 ? google_compute_health_check.default[0].id : (
    length(google_compute_region_health_check.internal) > 0 ? google_compute_region_health_check.internal[0].id : null
  )
}

output "health_check_self_link" {
  description = "헬스 체크 셀프 링크"
  value = length(google_compute_health_check.default) > 0 ? google_compute_health_check.default[0].self_link : (
    length(google_compute_region_health_check.internal) > 0 ? google_compute_region_health_check.internal[0].self_link : null
  )
}

output "url_map_id" {
  description = "URL 맵 ID"
  value       = length(google_compute_url_map.default) > 0 ? google_compute_url_map.default[0].id : null
}

output "url_map_self_link" {
  description = "URL 맵 셀프 링크"
  value       = length(google_compute_url_map.default) > 0 ? google_compute_url_map.default[0].self_link : null
}

output "target_http_proxy_id" {
  description = "HTTP 프록시 ID"
  value       = length(google_compute_target_http_proxy.default) > 0 ? google_compute_target_http_proxy.default[0].id : null
}

output "target_https_proxy_id" {
  description = "HTTPS 프록시 ID"
  value       = length(google_compute_target_https_proxy.default) > 0 ? google_compute_target_https_proxy.default[0].id : null
}

output "forwarding_rule_id" {
  description = "포워딩 규칙 ID"
  value = length(google_compute_global_forwarding_rule.http) > 0 ? google_compute_global_forwarding_rule.http[0].id : (
    length(google_compute_global_forwarding_rule.https) > 0 ? google_compute_global_forwarding_rule.https[0].id : (
      length(google_compute_forwarding_rule.internal) > 0 ? google_compute_forwarding_rule.internal[0].id : null
    )
  )
}

output "forwarding_rule_ip_address" {
  description = "포워딩 규칙 IP 주소"
  value = length(google_compute_global_forwarding_rule.http) > 0 ? google_compute_global_forwarding_rule.http[0].ip_address : (
    length(google_compute_global_forwarding_rule.https) > 0 ? google_compute_global_forwarding_rule.https[0].ip_address : (
      length(google_compute_forwarding_rule.internal) > 0 ? google_compute_forwarding_rule.internal[0].ip_address : null
    )
  )
}

output "static_ip_address" {
  description = "고정 IP 주소"
  value = length(google_compute_global_address.default) > 0 ? google_compute_global_address.default[0].address : (
    length(google_compute_address.internal) > 0 ? google_compute_address.internal[0].address : null
  )
}

output "lb_type" {
  description = "로드 밸런서 타입"
  value       = var.lb_type
}
