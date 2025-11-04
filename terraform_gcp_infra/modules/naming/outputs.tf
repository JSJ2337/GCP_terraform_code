output "project_name" {
  value = var.project_name
}

output "environment" {
  value = var.environment
}

output "organization" {
  value = var.organization
}

output "region_primary" {
  value = var.region_primary
}

output "region_backup" {
  value = var.region_backup
}

output "default_zone" {
  value = local.default_zone
}

output "project_prefix" {
  value = local.project_prefix
}

output "resource_prefix" {
  value = local.resource_prefix
}

output "bucket_name_prefix" {
  value = local.bucket_name_prefix
}

output "vpc_name" {
  value = local.vpc_name
}

output "subnet_name_primary" {
  value = local.subnet_name_primary
}

output "subnet_name_backup" {
  value = local.subnet_name_backup
}

output "pods_range_name" {
  value = local.pods_range_name
}

output "services_range_name" {
  value = local.services_range_name
}

output "cloud_router_name" {
  value = local.cloud_router_name
}

output "cloud_nat_name" {
  value = local.cloud_nat_name
}

output "vm_name_prefix" {
  value = local.vm_name_prefix
}

output "instance_group_name" {
  value = local.instance_group_name
}

output "instance_template_name" {
  value = local.instance_template_name
}

output "db_instance_name" {
  value = local.db_instance_name
}

output "backend_service_name" {
  value = local.backend_service_name
}

output "forwarding_rule_name" {
  value = local.forwarding_rule_name
}

output "health_check_name" {
  value = local.health_check_name
}

output "redis_instance_name" {
  value = local.redis_instance_name
}

output "sa_name_prefix" {
  value = local.sa_name_prefix
}

output "kms_keyring_name" {
  value = local.kms_keyring_name
}

output "common_labels" {
  value = local.common_labels
}

output "common_tags" {
  value = local.common_tags
}
