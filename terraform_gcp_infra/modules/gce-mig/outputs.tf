output "instance_group_manager_self_links" {
  description = "MIG self links"
  value       = { for k, v in google_compute_instance_group_manager.this : k => v.self_link }
}

output "instance_groups" {
  description = "Instance group URLs for Load Balancer 백엔드"
  value       = { for k, v in google_compute_instance_group_manager.this : k => v.instance_group }
}
