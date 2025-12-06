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

output "psc_service_attachments" {
  description = "PSC Service Attachments (use this for PSC Endpoint target)"
  value       = module.cache.psc_service_attachments
}

output "psc_service_attachment_link" {
  description = "Primary PSC Service Attachment Link (for PSC endpoints - Discovery)"
  value       = module.cache.psc_service_attachment_link
}

output "psc_service_attachment_links" {
  description = "All PSC Service Attachment Links as a list (for cross-project PSC endpoints)"
  value       = module.cache.psc_service_attachment_links
}

output "cluster_endpoints" {
  description = "Cluster endpoints with PSC connection details"
  value       = module.cache.cluster_endpoints
}

output "enable_cross_project_psc" {
  description = "Cross-project PSC 연결 활성화 여부"
  value       = var.enable_cross_project_psc
}
