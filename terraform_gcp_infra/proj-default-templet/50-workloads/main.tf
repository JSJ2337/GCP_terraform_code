terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

}

provider "google" {
  project = var.project_id
  region  = var.region
  user_project_override = true
  billing_project       = var.project_id
}

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

locals {
  zone = length(trimspace(var.zone)) > 0 ? var.zone : module.naming.default_zone

  subnetwork_self_link = length(trimspace(var.subnetwork_self_link)) > 0 ? var.subnetwork_self_link : "projects/${var.project_id}/regions/${module.naming.region_primary}/subnetworks/${module.naming.subnet_name_primary}"

  name_prefix = length(trimspace(var.name_prefix)) > 0 ? var.name_prefix : module.naming.vm_name_prefix

  service_account_email = length(trimspace(var.service_account_email)) > 0 ? var.service_account_email : "${module.naming.sa_name_prefix}-compute@${var.project_id}.iam.gserviceaccount.com"

  tags   = distinct(concat(module.naming.common_tags, var.tags))
  labels = merge(module.naming.common_labels, var.labels)
}

# Naming conventions supplied by modules/naming

module "gce_vmset" {
  source = "../../../../modules/gce-vmset"

  project_id           = var.project_id
  zone                 = length(trimspace(var.zone)) > 0 ? var.zone : module.naming.default_zone
  subnetwork_self_link = local.subnetwork_self_link

  # 기존 count 방식 (하위 호환성)
  instance_count = var.instance_count
  name_prefix    = local.name_prefix
  machine_type   = var.machine_type

  # 새로운 for_each 방식 (권장)
  instances = var.instances

  enable_public_ip = var.enable_public_ip
  enable_os_login  = var.enable_os_login
  preemptible      = var.preemptible

  startup_script = var.startup_script
  image_family   = var.image_family
  image_project  = var.image_project
  boot_disk_size_gb = var.boot_disk_size_gb
  boot_disk_type    = var.boot_disk_type
  metadata          = var.metadata

  service_account_email  = local.service_account_email
  service_account_scopes = var.service_account_scopes

  tags   = local.tags
  labels = local.labels
}
