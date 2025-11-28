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
      # zone 결정 우선순위: 1. zone (직접 지정) 2. zone_suffix (region과 결합) 3. 기본값
      # zone이 이미 있으면 zone 사용, 없으면 zone_suffix를 region_primary와 결합
      try(cfg.zone, null) != null && length(trimspace(cfg.zone)) > 0 ?
      {} : # zone이 직접 지정되어 있으면 그대로 사용 (위 필터링에서 통과됨)
      try(cfg.zone_suffix, null) != null && length(trimspace(cfg.zone_suffix)) > 0 ?
      { zone = "${module.naming.region_primary}-${trimspace(cfg.zone_suffix)}" } :
      {}
    )
  }

  vm_details = module.gce_vmset.vm_details
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
