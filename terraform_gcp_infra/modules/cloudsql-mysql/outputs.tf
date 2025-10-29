output "instance_name" {
  description = "Cloud SQL 인스턴스 이름"
  value       = google_sql_database_instance.instance.name
}

output "instance_connection_name" {
  description = "인스턴스 연결 이름 (project:region:instance)"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_self_link" {
  description = "인스턴스 셀프 링크"
  value       = google_sql_database_instance.instance.self_link
}

output "instance_ip_address" {
  description = "인스턴스 IP 주소"
  value = {
    private = length(google_sql_database_instance.instance.ip_address) > 0 ? [
      for ip in google_sql_database_instance.instance.ip_address : ip.ip_address if ip.type == "PRIVATE"
    ] : []
    public = length(google_sql_database_instance.instance.ip_address) > 0 ? [
      for ip in google_sql_database_instance.instance.ip_address : ip.ip_address if ip.type == "PRIMARY"
    ] : []
  }
}

output "instance_first_ip_address" {
  description = "첫 번째 IP 주소 (private 우선)"
  value       = google_sql_database_instance.instance.first_ip_address
}

output "instance_private_ip_address" {
  description = "Private IP 주소"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "instance_public_ip_address" {
  description = "Public IP 주소"
  value       = google_sql_database_instance.instance.public_ip_address
}

output "instance_server_ca_cert" {
  description = "서버 CA 인증서"
  value       = google_sql_database_instance.instance.server_ca_cert
  sensitive   = true
}

output "database_names" {
  description = "생성된 데이터베이스 이름 목록"
  value       = [for db in google_sql_database.databases : db.name]
}

output "user_names" {
  description = "생성된 사용자 이름 목록"
  value       = [for user in google_sql_user.users : user.name]
}

output "read_replica_connection_names" {
  description = "읽기 복제본 연결 이름"
  value       = { for k, replica in google_sql_database_instance.read_replicas : k => replica.connection_name }
}

output "read_replica_ip_addresses" {
  description = "읽기 복제본 IP 주소"
  value       = { for k, replica in google_sql_database_instance.read_replicas : k => replica.first_ip_address }
}
