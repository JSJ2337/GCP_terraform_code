terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

# Managed Zone 생성 (Public 또는 Private)
resource "google_dns_managed_zone" "zone" {
  project = var.project_id
  name    = var.zone_name
  dns_name = var.dns_name

  description = var.description

  # Public Zone인 경우 visibility = "public" (기본값)
  # Private Zone인 경우 visibility = "private" + private_visibility_config 설정
  visibility = var.visibility

  dynamic "private_visibility_config" {
    for_each = var.visibility == "private" ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_networks
        content {
          network_url = networks.value
        }
      }
    }
  }

  # DNSSEC 설정
  dynamic "dnssec_config" {
    for_each = var.enable_dnssec ? [1] : []
    content {
      state = "on"

      dynamic "default_key_specs" {
        for_each = var.dnssec_key_specs
        content {
          algorithm  = default_key_specs.value.algorithm
          key_length = default_key_specs.value.key_length
          key_type   = default_key_specs.value.key_type
        }
      }
    }
  }

  # Forwarding 설정 (Private Zone에서 외부 DNS로 전달)
  dynamic "forwarding_config" {
    for_each = length(var.target_name_servers) > 0 ? [1] : []
    content {
      dynamic "target_name_servers" {
        for_each = var.target_name_servers
        content {
          ipv4_address    = target_name_servers.value.ipv4_address
          forwarding_path = lookup(target_name_servers.value, "forwarding_path", "default")
        }
      }
    }
  }

  # Peering 설정 (다른 VPC의 DNS Zone과 연결)
  dynamic "peering_config" {
    for_each = var.peering_network != "" ? [1] : []
    content {
      target_network {
        network_url = var.peering_network
      }
    }
  }

  labels = var.labels
}

# DNS Records 생성
resource "google_dns_record_set" "records" {
  for_each = { for record in var.dns_records : "${record.name}-${record.type}" => record }

  project      = var.project_id
  managed_zone = google_dns_managed_zone.zone.name

  # name이 이미 FQDN(trailing dot)이면 그대로, 아니면 dns_name을 붙임
  name    = endswith(each.value.name, ".") ? each.value.name : "${each.value.name}.${var.dns_name}"
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", 300)
  rrdatas = each.value.rrdatas
}

# DNS Policy (Private Zone용 추가 설정)
resource "google_dns_policy" "policy" {
  count = var.create_dns_policy ? 1 : 0

  project = var.project_id
  name    = var.dns_policy_name

  description = var.dns_policy_description

  enable_inbound_forwarding = var.enable_inbound_forwarding
  enable_logging            = var.enable_dns_logging

  dynamic "alternative_name_server_config" {
    for_each = length(var.alternative_name_servers) > 0 ? [1] : []
    content {
      dynamic "target_name_servers" {
        for_each = var.alternative_name_servers
        content {
          ipv4_address    = target_name_servers.value.ipv4_address
          forwarding_path = lookup(target_name_servers.value, "forwarding_path", "default")
        }
      }
    }
  }

  dynamic "networks" {
    for_each = var.dns_policy_networks
    content {
      network_url = networks.value
    }
  }
}
