output "bucket_names" {
  description = "Map of all bucket names"
  value       = module.game_storage.bucket_names
}

output "bucket_urls" {
  description = "Map of all bucket URLs"
  value       = module.game_storage.bucket_urls
}

output "assets_bucket_name" {
  description = "The name of the assets bucket"
  value       = module.game_storage.bucket_names["assets"]
}

output "assets_bucket_url" {
  description = "The URL of the assets bucket"
  value       = module.game_storage.bucket_urls["assets"]
}

output "logs_bucket_name" {
  description = "The name of the logs bucket"
  value       = module.game_storage.bucket_names["logs"]
}

output "logs_bucket_url" {
  description = "The URL of the logs bucket"
  value       = module.game_storage.bucket_urls["logs"]
}

output "backups_bucket_name" {
  description = "The name of the backups bucket"
  value       = module.game_storage.bucket_names["backups"]
}

output "backups_bucket_url" {
  description = "The URL of the backups bucket"
  value       = module.game_storage.bucket_urls["backups"]
}