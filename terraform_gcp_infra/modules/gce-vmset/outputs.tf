locals {
  # 두 방식 모두 지원하도록 병합
  all_instances = merge(
    { for i in google_compute_instance.vm_count : i.name => i },
    google_compute_instance.vm_map
  )
}

output "instances" {
  description = "List of instance details"
  value = [
    for i in local.all_instances : {
      name        = i.name
      zone        = i.zone
      self_link   = i.self_link
      internal_ip = i.network_interface[0].network_ip
      external_ip = try(i.network_interface[0].access_config[0].nat_ip, null)
    }
  ]
}

output "instance_names" {
  description = "List of instance names"
  value       = [for i in local.all_instances : i.name]
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = [for i in local.all_instances : i.network_interface[0].network_ip]
}

output "self_links" {
  description = "List of instance self links"
  value       = [for i in local.all_instances : i.self_link]
}

output "instance_map" {
  description = "Map of instance details (for_each용)"
  value = {
    for name, i in local.all_instances : name => {
      name        = i.name
      zone        = i.zone
      self_link   = i.self_link
      internal_ip = i.network_interface[0].network_ip
      external_ip = try(i.network_interface[0].access_config[0].nat_ip, null)
    }
  }
}
