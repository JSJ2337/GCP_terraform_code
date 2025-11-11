terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

data "google_compute_image" "default" {
  family  = var.image_family
  project = var.image_project
}

data "google_compute_image" "per_instance" {
  for_each = var.instances
  family   = coalesce(each.value.image_family, var.image_family)
  project  = coalesce(each.value.image_project, var.image_project)
}

# 기존 count 방식 (하위 호환성 유지)
resource "google_compute_instance" "vm_count" {
  count        = length(var.instances) == 0 ? var.instance_count : 0
  name         = format("%s-%02d", var.name_prefix, count.index + 1)
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags
  labels       = var.labels
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = data.google_compute_image.default.self_link
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

# 새로운 for_each 방식 (권장)
resource "google_compute_instance" "vm_map" {
  for_each = var.instances

  name     = each.key
  hostname = try(each.value.hostname, null)

  machine_type = coalesce(each.value.machine_type, var.machine_type)
  zone         = coalesce(each.value.zone, var.zone)
  tags         = coalesce(each.value.tags, var.tags)
  labels       = merge(var.labels, coalesce(each.value.labels, {}))
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = data.google_compute_image.per_instance[each.key].self_link
      size  = coalesce(each.value.boot_disk_size_gb, var.boot_disk_size_gb)
      type  = coalesce(each.value.boot_disk_type, var.boot_disk_type)
    }
  }

  network_interface {
    subnetwork = coalesce(each.value.subnetwork_self_link, var.subnetwork_self_link)

    dynamic "access_config" {
      for_each = coalesce(each.value.enable_public_ip, var.enable_public_ip) ? [1] : []
      content {}
    }
  }

  metadata = merge(
    var.metadata,
    coalesce(each.value.metadata, {}),
    {
      enable-oslogin = coalesce(each.value.enable_os_login, var.enable_os_login) ? "TRUE" : "FALSE"
    }
  )

  metadata_startup_script = coalesce(each.value.startup_script, var.startup_script)

  scheduling {
    automatic_restart   = coalesce(each.value.preemptible, var.preemptible) ? false : true
    on_host_maintenance = coalesce(each.value.preemptible, var.preemptible) ? "TERMINATE" : "MIGRATE"
    provisioning_model  = coalesce(each.value.preemptible, var.preemptible) ? "SPOT" : "STANDARD"
    preemptible         = coalesce(each.value.preemptible, var.preemptible)
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  dynamic "service_account" {
    for_each = coalesce(each.value.service_account_email, var.service_account_email) != "" ? [coalesce(each.value.service_account_email, var.service_account_email)] : []
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }
}
