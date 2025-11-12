output "vm_details" {
  description = "Map of VM self links and zones keyed by instance name"
  value = {
    for name, inst in google_compute_instance.vm_map :
    name => {
      self_link = inst.self_link
      zone      = inst.zone
    }
  }
}
