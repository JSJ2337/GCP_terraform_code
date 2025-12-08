output "backend_service_id" {
  description = "백엔드 서비스 ID"
  value       = module.load_balancer.backend_service_id
}

output "health_check_id" {
  description = "헬스 체크 ID"
  value       = module.load_balancer.health_check_id
}

output "forwarding_rule_ip_address" {
  description = "로드 밸런서 IP 주소"
  value       = module.load_balancer.forwarding_rule_ip_address
}

output "static_ip_address" {
  description = "고정 IP 주소"
  value       = module.load_balancer.static_ip_address
}

output "lb_type" {
  description = "로드 밸런서 타입"
  value       = module.load_balancer.lb_type
}
