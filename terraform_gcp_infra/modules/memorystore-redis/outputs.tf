output "instance_name" {
  description = "Redis instance name"
  value       = google_redis_instance.this.name
}

output "host" {
  description = "Primary endpoint hostname"
  value       = google_redis_instance.this.host
}

output "read_endpoint" {
  description = "Read endpoint hostname (Enterprise tiers with replica_count >= 1)"
  value       = google_redis_instance.this.read_endpoint
}

output "port" {
  description = "Port number"
  value       = google_redis_instance.this.port
}

output "read_endpoint_port" {
  description = "Port used by the read endpoint"
  value       = google_redis_instance.this.read_endpoint_port
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

output "tier" {
  description = "Tier of the Redis instance"
  value       = google_redis_instance.this.tier
}

output "replica_count" {
  description = "Configured replica count (Enterprise tiers only)"
  value       = google_redis_instance.this.replica_count
}
