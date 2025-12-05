output "vm_details" {
  description = "Map of VM instance details (name, zone, self_link) for use in Load Balancer layer"
  value       = module.gce_vmset.vm_details
}
