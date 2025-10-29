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
  region  = "us-central1"
}

# Common naming conventions
locals {
  environment    = "prod"
  project_name   = "default-templet"
  project_prefix = "${local.environment}-${local.project_name}"

  # Default VM name prefix following naming convention
  default_vm_prefix = "${local.project_prefix}-vm"
}

module "gce_vmset" {
  source = "../../../../modules/gce-vmset"

  project_id           = var.project_id
  zone                 = var.zone
  subnetwork_self_link = var.subnetwork_self_link

  instance_count = var.instance_count
  name_prefix    = var.name_prefix != "" ? var.name_prefix : local.default_vm_prefix
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
