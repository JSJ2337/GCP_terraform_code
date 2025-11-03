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
}

locals {
  default_zone = "${var.region}-a"

  zone = length(trimspace(var.zone)) > 0 ? var.zone : local.default_zone

  subnetwork_self_link = length(trimspace(var.subnetwork_self_link)) > 0 ? var.subnetwork_self_link : "projects/${var.project_id}/regions/${local.region_primary}/subnetworks/${local.subnet_name_primary}"

  name_prefix = length(trimspace(var.name_prefix)) > 0 ? var.name_prefix : local.vm_name_prefix

  service_account_email = length(trimspace(var.service_account_email)) > 0 ? var.service_account_email : "${local.sa_name_prefix}-compute@${var.project_id}.iam.gserviceaccount.com"

  tags   = distinct(concat(local.common_tags, var.tags))
  labels = merge(local.common_labels, var.labels)
}

# Naming conventions imported from parent locals.tf
# local.vm_name_prefix is already defined in parent

module "gce_vmset" {
  source = "../../../../modules/gce-vmset"

  project_id           = var.project_id
  zone                 = local.zone
  subnetwork_self_link = local.subnetwork_self_link

  instance_count = var.instance_count
  name_prefix    = local.name_prefix
  machine_type   = var.machine_type

  enable_public_ip = var.enable_public_ip
  enable_os_login  = var.enable_os_login
  preemptible      = var.preemptible

  startup_script = var.startup_script

  service_account_email  = local.service_account_email
  service_account_scopes = var.service_account_scopes

  tags   = local.tags
  labels = local.labels
}
