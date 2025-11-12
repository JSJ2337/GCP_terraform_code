output "managed_instance_groups" {
  description = "Map of MIG instance group self links (Load Balancer 백엔드에서 사용)"
  value       = try(module.gce_mig.instance_groups, {})
}

output "managed_instance_group_managers" {
  description = "Map of MIG manager self links"
  value       = try(module.gce_mig.instance_group_manager_self_links, {})
}
