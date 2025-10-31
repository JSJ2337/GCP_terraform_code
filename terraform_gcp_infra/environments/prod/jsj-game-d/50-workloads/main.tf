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

# Naming conventions imported from parent locals.tf
# local.vm_name_prefix is already defined in parent

module "gce_vmset" {
  source = "../../../../modules/gce-vmset"

  project_id           = var.project_id
  zone                 = var.zone
  subnetwork_self_link = var.subnetwork_self_link

  instance_count = var.instance_count
  name_prefix    = var.name_prefix != "" ? var.name_prefix : local.vm_name_prefix
  machine_type   = var.machine_type

  enable_public_ip = var.enable_public_ip
  enable_os_login  = var.enable_os_login
  preemptible      = var.preemptible

  startup_script = var.startup_script

  service_account_email  = var.service_account_email
  service_account_scopes = var.service_account_scopes

  tags   = var.tags
  labels = var.labels
}
