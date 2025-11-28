# =============================================================================
# 20-storage Outputs
# =============================================================================

# Production State Bucket
output "tfstate_prod_bucket_name" {
  description = "Production Terraform State 버킷 이름"
  value       = google_storage_bucket.tfstate_prod.name
}

output "tfstate_prod_bucket_url" {
  description = "Production Terraform State 버킷 URL"
  value       = google_storage_bucket.tfstate_prod.url
}

# Development State Bucket
output "tfstate_dev_bucket_name" {
  description = "Development Terraform State 버킷 이름"
  value       = var.create_dev_bucket ? google_storage_bucket.tfstate_dev[0].name : null
}

output "tfstate_dev_bucket_url" {
  description = "Development Terraform State 버킷 URL"
  value       = var.create_dev_bucket ? google_storage_bucket.tfstate_dev[0].url : null
}

# Artifacts Bucket
output "artifacts_bucket_name" {
  description = "아티팩트 버킷 이름"
  value       = var.create_artifacts_bucket ? google_storage_bucket.artifacts[0].name : null
}

output "artifacts_bucket_url" {
  description = "아티팩트 버킷 URL"
  value       = var.create_artifacts_bucket ? google_storage_bucket.artifacts[0].url : null
}
