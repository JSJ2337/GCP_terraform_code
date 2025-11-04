terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
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
  vm_instance_regex_default          = format("^%s-\\d+$", module.naming.vm_name_prefix)
  cloudsql_instance_regex_default    = format("^%s:%s:%s$", var.project_id, var.region, module.naming.db_instance_name)
  memorystore_instance_regex_default = format("^projects/%s/locations/%s/instances/%s$", var.project_id, var.region, module.naming.redis_instance_name)
  lb_target_proxy_regex_default      = format("^%s-(http|https)-proxy$", module.naming.forwarding_rule_name)

  vm_instance_regex       = length(trimspace(var.vm_instance_regex)) > 0 ? var.vm_instance_regex : local.vm_instance_regex_default
  cloudsql_instance_regex = length(trimspace(var.cloudsql_instance_regex)) > 0 ? var.cloudsql_instance_regex : local.cloudsql_instance_regex_default
  redis_instance_regex    = length(trimspace(var.memorystore_instance_regex)) > 0 ? var.memorystore_instance_regex : local.memorystore_instance_regex_default
  lb_target_proxy_regex   = length(trimspace(var.lb_target_proxy_regex)) > 0 ? var.lb_target_proxy_regex : local.lb_target_proxy_regex_default
}

module "obs" {
  source = "../../../../modules/observability"

  project_id = var.project_id

  enable_central_log_sink = var.enable_central_log_sink
  central_logging_project = var.central_logging_project
  central_logging_bucket  = var.central_logging_bucket
  log_filter              = var.log_filter

  dashboard_json_files  = var.dashboard_json_files
  notification_channels = var.notification_channels

  enable_vm_cpu_alert      = var.enable_vm_cpu_alert
  vm_cpu_threshold         = var.vm_cpu_threshold
  vm_cpu_duration          = var.vm_cpu_duration
  vm_instance_filter_regex = local.vm_instance_regex

  enable_cloudsql_cpu_alert = var.enable_cloudsql_cpu_alert
  cloudsql_cpu_threshold    = var.cloudsql_cpu_threshold
  cloudsql_cpu_duration     = var.cloudsql_cpu_duration
  cloudsql_instance_regex   = local.cloudsql_instance_regex

  enable_memorystore_memory_alert = var.enable_memorystore_memory_alert
  memorystore_memory_threshold    = var.memorystore_memory_threshold
  memorystore_memory_duration     = var.memorystore_memory_duration
  memorystore_instance_regex      = local.redis_instance_regex

  enable_lb_5xx_alert   = var.enable_lb_5xx_alert
  lb_5xx_threshold      = var.lb_5xx_threshold
  lb_5xx_duration       = var.lb_5xx_duration
  lb_target_proxy_regex = local.lb_target_proxy_regex
}
