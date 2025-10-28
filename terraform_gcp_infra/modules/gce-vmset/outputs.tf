output "instances" {
  description = "List of instance details"
  value = [
    for i in google_compute_instance.vm : {
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
  value       = [for i in google_compute_instance.vm : i.name]
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = [for i in google_compute_instance.vm : i.network_interface[0].network_ip]
}

output "self_links" {
  description = "List of instance self links"
  value       = [for i in google_compute_instance.vm : i.self_link]
}
