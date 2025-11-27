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
  project               = var.project_id
  region                = var.region
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

  subnetwork_self_link = trimspace(var.subnetwork_self_link)

  name_prefix = length(trimspace(var.name_prefix)) > 0 ? var.name_prefix : module.naming.vm_name_prefix

  service_account_email = length(trimspace(var.service_account_email)) > 0 ? var.service_account_email : "${module.naming.sa_name_prefix}-compute@${var.project_id}.iam.gserviceaccount.com"

  tags   = distinct(concat(module.naming.common_tags, var.tags))
  labels = merge(module.naming.common_labels, var.labels)

  processed_instances = {
    for name, cfg in var.instances :
    name => merge(
      { for k, v in cfg : k => v if k != "startup_script_file" && k != "subnet_type" && k != "zone_suffix" },
      try(cfg.startup_script_file, null) != null ?
      { startup_script = file("${path.module}/${cfg.startup_script_file}") } :
      {},
      # subnet_type이 지정되면 subnets 맵에서 self_link 가져오기
      # 하위 호환성: subnet_type이 없으면 subnetwork_self_link 그대로 사용
      try(cfg.subnet_type, null) != null ?
      { subnetwork_self_link = var.subnets[cfg.subnet_type].self_link } :
      {},
      # zone_suffix를 실제 zone으로 변환
      try(cfg.zone_suffix, null) != null ?
      { zone = "${module.naming.region_primary}-${cfg.zone_suffix}" } :
      {}
    )
  }

  vm_details = module.gce_vmset.vm_details

  processed_instance_groups = {
    for name, cfg in var.instance_groups :
    name => {
      resolved_instances = [
        for inst_name in cfg.instances : {
          name      = inst_name
          self_link = local.vm_details[inst_name].self_link
          zone      = local.vm_details[inst_name].zone
        }
      ]
      zone = try(cfg.zone_suffix, null) != null ? "${module.naming.region_primary}-${cfg.zone_suffix}" : coalesce(cfg.zone, local.vm_details[cfg.instances[0]].zone)
      named_ports = coalesce(cfg.named_ports, [])
    }
    if length(cfg.instances) > 0
  }
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
  instances = local.processed_instances

  enable_public_ip = var.enable_public_ip
  enable_os_login  = var.enable_os_login
  preemptible      = var.preemptible

  startup_script    = var.startup_script
  image_family      = var.image_family
  image_project     = var.image_project
  boot_disk_size_gb = var.boot_disk_size_gb
  boot_disk_type    = var.boot_disk_type
  metadata          = var.metadata

  service_account_email  = local.service_account_email
  service_account_scopes = var.service_account_scopes

  tags   = local.tags
  labels = local.labels
}

resource "google_compute_instance_group" "custom" {
  for_each = local.processed_instance_groups

  project = var.project_id
  name    = each.key
  zone    = each.value.zone

  instances = [for inst in each.value.resolved_instances : inst.self_link]

  dynamic "named_port" {
    for_each = each.value.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  lifecycle {
    precondition {
      condition     = length(distinct([for inst in each.value.resolved_instances : inst.zone])) == 1
      error_message = "${each.key} instance group에는 동일한 존의 VM만 포함해야 합니다."
    }
  }
}
