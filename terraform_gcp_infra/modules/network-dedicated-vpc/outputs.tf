output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_ids" {
  value = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "private_service_connection_reserved_ranges" {
  value       = local.private_service_connection_reserved_ranges
  description = "Service Networking(Private Service Connect)에서 사용하는 예약 IP 범위 이름 목록"
}

output "private_service_connection_self_link" {
  value       = var.enable_private_service_connection ? google_service_networking_connection.private_vpc_connection[0].id : null
  description = "생성된 Service Networking 연결 ID (비활성화 시 null)"
}
