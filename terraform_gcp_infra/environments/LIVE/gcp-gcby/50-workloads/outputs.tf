output "instance_groups" {
  description = "Map of unmanaged instance group self links (Load Balancer에서 사용)"
  value       = { for k, v in google_compute_instance_group.custom : k => v.self_link }
}

# DEBUG: zone_suffix 변환 확인용
output "debug_processed_instances_zones" {
  description = "DEBUG: processed_instances의 zone 값 확인"
  value = {
    for name, cfg in local.processed_instances :
    name => lookup(cfg, "zone", "NO_ZONE_SET")
  }
}

output "debug_region_primary" {
  description = "DEBUG: module.naming.region_primary 값 확인"
  value       = module.naming.region_primary
}
