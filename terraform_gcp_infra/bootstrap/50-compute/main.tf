# =============================================================================
# 50-compute: Bootstrap VMs (gce-vmset 모듈과 동일한 형식)
# =============================================================================

data "google_compute_image" "default" {
  family  = var.image_family
  project = var.image_project
}

data "google_compute_image" "per_instance" {
  for_each = var.instances
  family   = coalesce(each.value.image_family, var.image_family)
  project  = coalesce(each.value.image_project, var.image_project)
}

# -----------------------------------------------------------------------------
# 1) Static IP (고정 외부 IP)
# -----------------------------------------------------------------------------
resource "google_compute_address" "static_ip" {
  for_each = { for k, v in var.instances : k => v if coalesce(v.create_static_ip, var.create_static_ip) }

  project      = var.management_project_id
  name         = "${each.key}-ip"
  region       = var.region_primary
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  labels = merge(var.labels, coalesce(each.value.labels, {}))
}

# -----------------------------------------------------------------------------
# 2) Boot Disk (인스턴스별)
# -----------------------------------------------------------------------------
resource "google_compute_disk" "boot" {
  for_each = var.instances

  project = var.management_project_id
  name    = "${each.key}-boot"
  zone    = coalesce(each.value.zone, var.zone)
  size    = coalesce(each.value.boot_disk_size_gb, var.boot_disk_size_gb)
  type    = coalesce(each.value.boot_disk_type, var.boot_disk_type)
  image   = data.google_compute_image.per_instance[each.key].self_link

  labels = merge(var.labels, coalesce(each.value.labels, {}), {
    purpose = "boot-disk"
  })
}

# -----------------------------------------------------------------------------
# 2) VM 인스턴스 (for_each 방식)
# -----------------------------------------------------------------------------
resource "google_compute_instance" "vm" {
  for_each = var.instances

  project  = var.management_project_id
  name     = each.key
  hostname = try(each.value.hostname, null)
  zone     = coalesce(each.value.zone, var.zone)

  machine_type = coalesce(each.value.machine_type, var.machine_type)
  tags         = coalesce(each.value.tags, var.tags)
  labels       = merge(var.labels, coalesce(each.value.labels, {}))

  boot_disk {
    source      = google_compute_disk.boot[each.key].self_link
    auto_delete = false
  }

  network_interface {
    subnetwork = var.subnet_self_link

    dynamic "access_config" {
      for_each = coalesce(each.value.enable_public_ip, var.enable_public_ip) ? [1] : []
      content {
        # 고정 IP가 있으면 사용, 없으면 임시 IP
        nat_ip = coalesce(each.value.create_static_ip, var.create_static_ip) ? google_compute_address.static_ip[each.key].address : null
      }
    }
  }

  metadata = merge(
    var.metadata,
    coalesce(each.value.metadata, {}),
    {
      enable-oslogin         = coalesce(each.value.enable_os_login, var.enable_os_login) ? "TRUE" : "FALSE"
      serial-port-enable     = "FALSE"
      block-project-ssh-keys = "TRUE"
    }
  )

  metadata_startup_script = try(coalesce(each.value.startup_script, var.startup_script), null)

  scheduling {
    automatic_restart   = coalesce(each.value.preemptible, var.preemptible) ? false : true
    on_host_maintenance = coalesce(each.value.preemptible, var.preemptible) ? "TERMINATE" : "MIGRATE"
    provisioning_model  = coalesce(each.value.preemptible, var.preemptible) ? "SPOT" : "STANDARD"
    preemptible         = coalesce(each.value.preemptible, var.preemptible)
  }

  # Shielded VM 설정
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  dynamic "service_account" {
    for_each = try(coalesce(each.value.service_account_email, var.service_account_email), "") != "" ? [try(coalesce(each.value.service_account_email, var.service_account_email), "")] : []
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }

  deletion_protection = coalesce(each.value.deletion_protection, var.deletion_protection)

  lifecycle {
    ignore_changes = [
      metadata_startup_script,
    ]
  }
}
