output "instance_name" {
  description = "Redis resource name"
  value       = try(google_redis_instance.standard[0].name, google_redis_cluster.enterprise[0].name)
}

output "host" {
  description = "Primary endpoint hostname (STANDARD tiers only)"
  value       = try(google_redis_instance.standard[0].host, null)
}

output "read_endpoint" {
  description = "Read endpoint hostname (STANDARD tiers or Memorystore instances that expose one)"
  value       = try(google_redis_instance.standard[0].read_endpoint, null)
}

output "port" {
  description = "Port number"
  value       = try(google_redis_instance.standard[0].port, 6379)
}

output "read_endpoint_port" {
  description = "Port used by the read endpoint"
  value       = try(google_redis_instance.standard[0].read_endpoint_port, null)
}

output "region" {
  description = "Deployment region/zone"
  value       = try(google_redis_instance.standard[0].location_id, google_redis_cluster.enterprise[0].region)
}

output "alternative_location_id" {
  description = "Secondary zone for STANDARD_HA tier"
  value       = try(google_redis_instance.standard[0].alternative_location_id, null)
}

output "authorized_network" {
  description = "Authorized network self link / PSC network"
  value       = var.authorized_network
}

output "tier" {
  description = "Requested tier"
  value       = var.tier
}

output "replica_count" {
  description = "Configured replica count (Enterprise tiers only)"
  value       = try(google_redis_cluster.enterprise[0].replica_count, null)
}

output "psc_connections" {
  description = "PSC connection metadata for Enterprise tiers"
  value       = try(google_redis_cluster.enterprise[0].psc_connections, [])
}

output "psc_service_attachments" {
  description = "PSC Service Attachments for Enterprise tiers (use this for PSC Endpoint target)"
  value       = try(google_redis_cluster.enterprise[0].psc_service_attachments, [])
}

output "psc_service_attachment_link" {
  description = "Primary PSC Service Attachment Link (for PSC endpoints - Discovery)"
  value       = try(google_redis_cluster.enterprise[0].psc_service_attachments[0].service_attachment, null)
}

output "psc_service_attachment_links" {
  description = "All PSC Service Attachment Links as a list (for cross-project PSC endpoints)"
  value = try([
    for sa in google_redis_cluster.enterprise[0].psc_service_attachments : sa.service_attachment
  ], [])
}

output "cluster_endpoints" {
  description = "Cluster endpoints with PSC connection details (Discovery endpoint info)"
  value = try({
    discovery_endpoints = google_redis_cluster.enterprise[0].discovery_endpoints
    psc_connections     = google_redis_cluster.enterprise[0].psc_connections
    psc_service_attachments = [
      for sa in google_redis_cluster.enterprise[0].psc_service_attachments : sa.service_attachment
    ]
  }, null)
}

output "cross_project_psc_info" {
  description = "Cross-project PSC connection information for manual registration"
  value       = local.cross_project_psc_info
}
