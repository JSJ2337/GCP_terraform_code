terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

data "google_compute_image" "os" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance" "vm" {
  count        = var.instance_count
  name         = format("%s-%02d", var.name_prefix, count.index + 1)
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.os.self_link
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = var.subnetwork_self_link

    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {}
    }
  }

  metadata = merge(
    var.metadata,
    {
      enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
    }
  )

  metadata_startup_script = var.startup_script

  scheduling {
    automatic_restart   = var.preemptible ? false : true
    on_host_maintenance = var.preemptible ? "TERMINATE" : "MIGRATE"
    provisioning_model  = var.preemptible ? "SPOT" : "STANDARD"
    preemptible         = var.preemptible
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  dynamic "service_account" {
    for_each = var.service_account_email != "" ? [var.service_account_email] : []
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }
}
