output "instance_name" {
  description = "Redis instance name"
  value       = google_redis_instance.this.name
}

output "host" {
  description = "Primary endpoint hostname"
  value       = google_redis_instance.this.host
}

output "port" {
  description = "Port number"
  value       = google_redis_instance.this.port
}

output "region" {
  description = "Region where the instance is deployed"
  value       = google_redis_instance.this.location_id
}

output "alternative_location_id" {
  description = "Secondary zone for STANDARD_HA tier"
  value       = google_redis_instance.this.alternative_location_id
}

output "authorized_network" {
  description = "Authorized network self link"
  value       = google_redis_instance.this.authorized_network
}
