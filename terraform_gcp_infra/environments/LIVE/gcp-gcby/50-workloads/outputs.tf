output "instance_groups" {
  description = "Map of unmanaged instance group self links (Load Balancer에서 사용)"
  value       = { for k, v in google_compute_instance_group.custom : k => v.self_link }
}

# DEBUG: zone_suffix 변환 확인용
output "debug_var_instances_raw" {
  description = "DEBUG: var.instances 원본 데이터 확인"
  value = {
    for name, cfg in var.instances :
    name => {
      has_zone        = try(cfg.zone, null) != null
      has_zone_suffix = try(cfg.zone_suffix, null) != null
      zone_suffix_val = try(cfg.zone_suffix, "NOT_SET")
      zone_val        = try(cfg.zone, "NOT_SET")
    }
  }
}

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
