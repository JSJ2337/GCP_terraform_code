output "instance_name" {
  description = "Memorystore Redis 인스턴스 이름"
  value       = module.cache.instance_name
}

output "host" {
  description = "Redis 연결용 호스트"
  value       = module.cache.host
}

output "port" {
  description = "Redis 포트"
  value       = module.cache.port
}

output "authorized_network" {
  description = "접근 허용된 VPC self link"
  value       = module.cache.authorized_network
}

output "psc_connections" {
  description = "PSC connection metadata"
  value       = module.cache.psc_connections
}

output "psc_service_attachment_link" {
  description = "Primary PSC Service Attachment Link (for PSC endpoints)"
  value       = length(module.cache.psc_connections) > 0 ? module.cache.psc_connections[0].service_attachment : null
}
