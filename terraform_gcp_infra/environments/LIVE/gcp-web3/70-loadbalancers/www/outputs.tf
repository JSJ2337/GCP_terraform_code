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

# Debug outputs - 문제 파악 후 삭제
output "debug_var_instance_groups" {
  description = "[DEBUG] terragrunt에서 전달받은 var.instance_groups"
  value       = var.instance_groups
}

output "debug_effective_vm_details_keys" {
  description = "[DEBUG] effective_vm_details의 키 목록"
  value       = keys(local.effective_vm_details)
}

output "debug_processed_instance_groups" {
  description = "[DEBUG] 최종 처리된 instance groups"
  value       = local.processed_instance_groups
}

output "debug_instance_group_ids" {
  description = "[DEBUG] 생성된 Instance Group IDs"
  value       = { for k, v in google_compute_instance_group.lb_instance_group : k => v.self_link }
}
