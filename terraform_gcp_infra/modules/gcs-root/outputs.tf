output "bucket_names" {
  description = "Map of bucket keys to bucket names"
  value       = { for k, v in module.gcs_buckets : k => v.bucket_name }
}

output "bucket_urls" {
  description = "Map of bucket keys to bucket URLs"
  value       = { for k, v in module.gcs_buckets : k => v.bucket_url }
}

output "bucket_self_links" {
  description = "Map of bucket keys to bucket self links"
  value       = { for k, v in module.gcs_buckets : k => v.bucket_self_link }
}

output "bucket_locations" {
  description = "Map of bucket keys to bucket locations"
  value       = { for k, v in module.gcs_buckets : k => v.bucket_location }
}

output "bucket_storage_classes" {
  description = "Map of bucket keys to storage classes"
  value       = { for k, v in module.gcs_buckets : k => v.bucket_storage_class }
}