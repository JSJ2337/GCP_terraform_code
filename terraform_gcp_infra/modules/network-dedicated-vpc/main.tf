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
  # direction/ports 등 기본값을 적용해 단일 포맷으로 정규화
  normalized_firewall_rules = {
    for rule in var.firewall_rules : rule.name => {
      direction      = lookup(rule, "direction", "INGRESS")
      ranges         = lookup(rule, "ranges", null)
      allow_protocol = lookup(rule, "allow_protocol", "tcp")
      allow_ports    = lookup(rule, "allow_ports", [])
      priority       = lookup(rule, "priority", 1000)
      target_tags    = lookup(rule, "target_tags", null)
      disabled       = lookup(rule, "disabled", false)
      description    = lookup(rule, "description", null)
    }
  }
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  description             = "Dedicated VPC for ${var.project_id}"
}

resource "google_compute_subnetwork" "subnets" {
  for_each                 = var.subnets
  name                     = each.key
  project                  = var.project_id
  ip_cidr_range            = each.value.cidr
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = lookup(each.value, "private_google_access", true)

  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ranges", [])
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    metadata             = "INCLUDE_ALL_METADATA"
    flow_sampling        = 0.5
  }
}

resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-cr"
  region  = var.nat_region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat" {
  name                                = "${var.vpc_name}-nat"
  router                              = google_compute_router.router.name
  region                              = var.nat_region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                    = var.nat_min_ports_per_vm
  enable_endpoint_independent_mapping = true

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "rules" {
  for_each  = local.normalized_firewall_rules
  name      = each.key
  network   = google_compute_network.vpc.name
  direction = each.value.direction
  priority  = each.value.priority

  allow {
    protocol = each.value.allow_protocol
    ports    = each.value.allow_ports
  }

  source_ranges      = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? coalescelist(each.value.ranges, ["0.0.0.0/0"]) : null
  target_tags        = each.value.target_tags
  disabled           = each.value.disabled
  description        = each.value.description
}

output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_ids" {
  value = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}
