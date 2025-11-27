output "instance_groups" {
  description = "Map of unmanaged instance group self links (Load Balancer에서 사용)"
  value       = { for k, v in google_compute_instance_group.custom : k => v.self_link }
}
