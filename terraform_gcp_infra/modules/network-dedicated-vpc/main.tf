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

  use_existing_psc_ranges         = length(var.private_service_connection_existing_ranges) > 0
  private_service_connection_name = length(trimspace(var.private_service_connection_name)) > 0 ? var.private_service_connection_name : "${var.vpc_name}-psc"
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
  source_subnetwork_ip_ranges_to_nat  = length(var.nat_subnet_self_links) > 0 ? "LIST_OF_SUBNETWORKS" : "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                    = var.nat_min_ports_per_vm
  enable_endpoint_independent_mapping = true
  # depends_on 제거: subnet 삭제 시 NAT 업데이트가 먼저 일어나야 하므로
  # depends_on                          = [google_compute_subnetwork.subnets]

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  dynamic "subnetwork" {
    for_each = length(var.nat_subnet_self_links) > 0 ? var.nat_subnet_self_links : []
    content {
      name                    = subnetwork.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  lifecycle {
    # NAT 업데이트가 subnet 삭제보다 먼저 일어나도록 보장
    create_before_destroy = true
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

  source_ranges = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? (
    length(coalesce(each.value.ranges, [])) > 0 ? each.value.ranges : ["0.0.0.0/0"]
  ) : null
  target_tags = each.value.target_tags
  disabled    = each.value.disabled
  description = each.value.description
}

resource "google_compute_global_address" "private_service_connect" {
  count        = var.enable_private_service_connection && !local.use_existing_psc_ranges ? 1 : 0
  name         = local.private_service_connection_name
  project      = var.project_id
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"

  address       = length(trimspace(var.private_service_connection_address)) > 0 ? var.private_service_connection_address : null
  prefix_length = var.private_service_connection_prefix_length
  network       = google_compute_network.vpc.id
}

locals {
  private_service_connection_reserved_ranges = var.enable_private_service_connection ? (
    local.use_existing_psc_ranges ?
    var.private_service_connection_existing_ranges :
    [google_compute_global_address.private_service_connect[0].name]
  ) : []
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count   = var.enable_private_service_connection ? 1 : 0
  network = google_compute_network.vpc.self_link
  service = var.private_service_connection_service

  reserved_peering_ranges = local.private_service_connection_reserved_ranges

  # Terraform Provider Google 5.x 버그 우회: destroy 시 ABANDON으로 설정
  # VPC/프로젝트 삭제 시 자동으로 정리되므로 안전함
  deletion_policy = "ABANDON"

  depends_on = [google_compute_global_address.private_service_connect]
}
