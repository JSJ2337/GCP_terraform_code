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
