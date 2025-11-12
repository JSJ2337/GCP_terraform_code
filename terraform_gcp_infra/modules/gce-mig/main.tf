terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

locals {
  processed_groups = {
    for name, cfg in var.groups :
    name => {
      zone                  = cfg.zone
      target_size           = cfg.target_size
      subnetwork_self_link  = cfg.subnetwork_self_link
      enable_public_ip      = coalesce(cfg.enable_public_ip, false)
      machine_type          = coalesce(cfg.machine_type, var.machine_type)
      startup_script        = coalesce(cfg.startup_script, var.startup_script)
      metadata              = merge(var.metadata, coalesce(cfg.metadata, {}))
      tags                  = distinct(concat(var.tags, coalesce(cfg.tags, [])))
      labels                = merge(var.labels, coalesce(cfg.labels, {}))
      boot_disk_size_gb     = coalesce(cfg.boot_disk_size_gb, var.boot_disk_size_gb)
      boot_disk_type        = coalesce(cfg.boot_disk_type, var.boot_disk_type)
      image_family          = coalesce(cfg.image_family, var.image_family)
      image_project         = coalesce(cfg.image_project, var.image_project)
      service_account_email = coalesce(cfg.service_account_email, var.service_account_email)
      named_ports           = coalesce(cfg.named_ports, [])
    }
  }
}

data "google_compute_image" "group" {
  for_each = local.processed_groups
  family   = each.value.image_family
  project  = each.value.image_project
}

resource "google_compute_instance_template" "this" {
  for_each = local.processed_groups

  project      = var.project_id
  name_prefix  = "${each.key}-tmpl"
  machine_type = each.value.machine_type
  tags         = each.value.tags
  labels       = each.value.labels
  metadata     = each.value.metadata

  metadata_startup_script = each.value.startup_script

  disk {
    auto_delete  = true
    boot         = true
    disk_size_gb = each.value.boot_disk_size_gb
    disk_type    = each.value.boot_disk_type
    source_image = data.google_compute_image.group[each.key].self_link
  }

  network_interface {
    subnetwork = each.value.subnetwork_self_link

    dynamic "access_config" {
      for_each = each.value.enable_public_ip ? [1] : []
      content {}
    }
  }

  dynamic "service_account" {
    for_each = trimspace(each.value.service_account_email) != "" ? [each.value.service_account_email] : []
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }
}

resource "google_compute_instance_group_manager" "this" {
  for_each = local.processed_groups

  project            = var.project_id
  name               = "${each.key}-mig"
  base_instance_name = each.key
  zone               = each.value.zone
  target_size        = each.value.target_size

  version {
    name              = "primary"
    instance_template = google_compute_instance_template.this[each.key].self_link
  }

  lifecycle {
    create_before_destroy = true
  }

  dynamic "named_port" {
    for_each = each.value.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }
}
