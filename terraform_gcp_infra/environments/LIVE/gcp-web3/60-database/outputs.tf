output "instance_name" {
  description = "Cloud SQL 인스턴스 이름"
  value       = module.mysql.instance_name
}

output "instance_connection_name" {
  description = "인스턴스 연결 이름"
  value       = module.mysql.instance_connection_name
}

output "instance_private_ip_address" {
  description = "Private IP 주소"
  value       = module.mysql.instance_private_ip_address
}

output "instance_public_ip_address" {
  description = "Public IP 주소"
  value       = module.mysql.instance_public_ip_address
}

output "database_names" {
  description = "생성된 데이터베이스 이름 목록"
  value       = module.mysql.database_names
}

output "user_names" {
  description = "생성된 사용자 이름 목록"
  value       = module.mysql.user_names
}

output "psc_service_attachment_link" {
  description = "PSC Service Attachment Link"
  value       = module.mysql.psc_service_attachment_link
}
