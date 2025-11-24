terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

# 전역 헬스 체크 (HTTP(S) 및 Internal LB용)
resource "google_compute_health_check" "default" {
  count = var.create_health_check && var.lb_type != "internal_classic" ? 1 : 0

  name    = var.health_check_name
  project = var.project_id

  lifecycle {
    create_before_destroy = true
  }

  timeout_sec         = var.health_check_timeout
  check_interval_sec  = var.health_check_interval
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  dynamic "http_health_check" {
    for_each = var.health_check_type == "http" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      response           = var.health_check_response
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "https_health_check" {
    for_each = var.health_check_type == "https" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      response           = var.health_check_response
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "tcp_health_check" {
    for_each = var.health_check_type == "tcp" ? [1] : []
    content {
      port               = var.health_check_port
      port_specification = var.health_check_port_specification
    }
  }

  log_config {
    enable = var.health_check_logging
  }
}

# 리전 헬스 체크 (Internal Classic LB용)
resource "google_compute_region_health_check" "internal" {
  count = var.create_health_check && var.lb_type == "internal_classic" ? 1 : 0

  name    = var.health_check_name
  project = var.project_id
  region  = var.region

  lifecycle {
    create_before_destroy = true
  }

  timeout_sec         = var.health_check_timeout
  check_interval_sec  = var.health_check_interval
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  dynamic "http_health_check" {
    for_each = var.health_check_type == "http" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      response           = var.health_check_response
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "https_health_check" {
    for_each = var.health_check_type == "https" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      response           = var.health_check_response
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "tcp_health_check" {
    for_each = var.health_check_type == "tcp" ? [1] : []
    content {
      port               = var.health_check_port
      port_specification = var.health_check_port_specification
    }
  }

  log_config {
    enable = var.health_check_logging
  }
}

# 백엔드 서비스 (HTTP(S)/Internal LB)
resource "google_compute_backend_service" "default" {
  count = var.lb_type == "http" || var.lb_type == "internal" ? 1 : 0

  name        = var.backend_service_name
  project     = var.project_id
  protocol    = var.lb_type == "http" ? var.backend_protocol : "TCP"
  port_name   = var.backend_port_name
  timeout_sec = var.backend_timeout

  health_checks = var.create_health_check ? [google_compute_health_check.default[0].id] : var.health_check_ids

  dynamic "backend" {
    for_each = var.backends
    content {
      group           = backend.value.group
      balancing_mode  = lookup(backend.value, "balancing_mode", "UTILIZATION")
      capacity_scaler = lookup(backend.value, "capacity_scaler", 1.0)
      description     = lookup(backend.value, "description", null)
      max_utilization = lookup(backend.value, "max_utilization", 0.8)
    }
  }

  # 세션 고정 설정
  session_affinity        = var.session_affinity
  affinity_cookie_ttl_sec = var.session_affinity == "GENERATED_COOKIE" ? var.affinity_cookie_ttl : null

  # 연결 드레이닝
  connection_draining_timeout_sec = var.connection_draining_timeout

  # CDN 설정 (HTTP(S) 전용)
  dynamic "cdn_policy" {
    for_each = var.lb_type == "http" && var.enable_cdn ? [1] : []
    content {
      cache_mode        = var.cdn_cache_mode
      default_ttl       = var.cdn_default_ttl
      max_ttl           = var.cdn_max_ttl
      client_ttl        = var.cdn_client_ttl
      negative_caching  = var.cdn_negative_caching
      serve_while_stale = var.cdn_serve_while_stale
    }
  }

  # IAP 설정 (HTTP(S) 전용)
  dynamic "iap" {
    for_each = var.lb_type == "http" && var.enable_iap ? [1] : []
    content {
      enabled              = true
      oauth2_client_id     = var.iap_oauth2_client_id
      oauth2_client_secret = var.iap_oauth2_client_secret
    }
  }

  # 로깅
  log_config {
    enable      = var.enable_logging
    sample_rate = var.logging_sample_rate
  }

  # Internal LB 전용 설정
  load_balancing_scheme = var.lb_type == "internal" ? "INTERNAL_MANAGED" : "EXTERNAL_MANAGED"
}

# Terraform GCP Provider 버그 워크어라운드:
# Backend Service destroy 시 Instance Group을 자동으로 detach하지 않는 문제 해결
# 참고: https://github.com/hashicorp/terraform-provider-google/issues/6376
resource "null_resource" "backend_cleanup" {
  count = var.lb_type == "http" || var.lb_type == "internal" ? 1 : 0

  triggers = {
    backend_service_name = var.backend_service_name
    project_id           = var.project_id
    # backends를 JSON으로 인코딩하여 변경 감지
    backends_json = jsonencode([
      for b in var.backends : {
        group = b.group
      }
    ])
  }

  # Destroy 시 Backend Service에서 모든 backend를 명시적으로 제거
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e

      echo "🧹 Cleaning up backends from Backend Service: ${self.triggers.backend_service_name}"

      # Backend Service에서 모든 backend 조회
      backends=$(gcloud compute backend-services describe ${self.triggers.backend_service_name} \
        --global \
        --project=${self.triggers.project_id} \
        --format='value(backends[].group)' 2>&1 || echo "NONE")

      if [ "$backends" != "NONE" ] && [ -n "$backends" ]; then
        echo "$backends" | while IFS= read -r backend_url; do
          if [ -n "$backend_url" ]; then
            # URL에서 zone과 instance group 이름 파싱
            # URL 형식: https://www.googleapis.com/compute/v1/projects/PROJECT/zones/ZONE/instanceGroups/NAME
            ig_name=$(echo "$backend_url" | awk -F'/' '{print $NF}')
            zone=$(echo "$backend_url" | awk -F'/' '{for(i=1;i<=NF;i++) if($i=="zones") print $(i+1)}')

            echo "  Removing backend: $ig_name (zone: $zone)"
            gcloud compute backend-services remove-backend ${self.triggers.backend_service_name} \
              --instance-group="$ig_name" \
              --instance-group-zone="$zone" \
              --global \
              --project=${self.triggers.project_id} \
              --quiet || echo "    Warning: Could not remove backend $ig_name"

            sleep 2
          fi
        done

        echo "✅ All backends removed from ${self.triggers.backend_service_name}"
      else
        echo "✅ No backends found in ${self.triggers.backend_service_name}"
      fi
    EOT
  }

  depends_on = [google_compute_backend_service.default]
}

# 리전 백엔드 서비스 (Internal Classic LB)
resource "google_compute_region_backend_service" "internal" {
  count = var.lb_type == "internal_classic" ? 1 : 0

  name     = var.backend_service_name
  project  = var.project_id
  region   = var.region
  protocol = "TCP"

  health_checks = var.create_health_check ? [google_compute_region_health_check.internal[0].id] : var.health_check_ids

  dynamic "backend" {
    for_each = var.backends
    content {
      group       = backend.value.group
      description = lookup(backend.value, "description", null)
    }
  }

  session_affinity                = var.session_affinity
  connection_draining_timeout_sec = var.connection_draining_timeout

  load_balancing_scheme = "INTERNAL"
}

# URL 맵 (HTTP(S) LB)
resource "google_compute_url_map" "default" {
  count = var.lb_type == "http" ? 1 : 0

  name            = var.url_map_name != "" ? var.url_map_name : "${var.backend_service_name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.default[0].id

  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }

  dynamic "path_matcher" {
    for_each = var.path_matchers
    content {
      name            = path_matcher.value.name
      default_service = path_matcher.value.default_service

      dynamic "path_rule" {
        for_each = lookup(path_matcher.value, "path_rules", [])
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.service
        }
      }
    }
  }
}

# Target HTTP 프록시
resource "google_compute_target_http_proxy" "default" {
  count = var.lb_type == "http" && !var.use_ssl ? 1 : 0

  name    = var.target_http_proxy_name != "" ? var.target_http_proxy_name : "${var.backend_service_name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.default[0].id
}

# Target HTTPS 프록시
resource "google_compute_target_https_proxy" "default" {
  count = var.lb_type == "http" && var.use_ssl ? 1 : 0

  name             = var.target_https_proxy_name != "" ? var.target_https_proxy_name : "${var.backend_service_name}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.default[0].id
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy != "" ? var.ssl_policy : null
}

# 글로벌 포워딩 규칙 - HTTP
resource "google_compute_global_forwarding_rule" "http" {
  count = var.lb_type == "http" && !var.use_ssl ? 1 : 0

  name       = var.forwarding_rule_name
  project    = var.project_id
  target     = google_compute_target_http_proxy.default[0].id
  port_range = "80"
  ip_address = var.create_static_ip ? google_compute_global_address.default[0].address : (var.static_ip_address != "" ? var.static_ip_address : null)

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# 글로벌 포워딩 규칙 - HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  count = var.lb_type == "http" && var.use_ssl ? 1 : 0

  name       = var.forwarding_rule_name
  project    = var.project_id
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = var.create_static_ip ? google_compute_global_address.default[0].address : (var.static_ip_address != "" ? var.static_ip_address : null)

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# 리전 포워딩 규칙 - Internal LB
resource "google_compute_forwarding_rule" "internal" {
  count = var.lb_type == "internal" || var.lb_type == "internal_classic" ? 1 : 0

  name                  = var.forwarding_rule_name
  project               = var.project_id
  region                = var.region
  network               = var.network
  subnetwork            = var.subnetwork
  backend_service       = var.lb_type == "internal" ? google_compute_backend_service.default[0].id : google_compute_region_backend_service.internal[0].id
  load_balancing_scheme = var.lb_type == "internal" ? "INTERNAL_MANAGED" : "INTERNAL"
  ip_address            = var.create_static_ip ? google_compute_address.internal[0].address : (var.static_ip_address != "" ? var.static_ip_address : null)
  ports                 = var.forwarding_rule_ports
  all_ports             = var.forwarding_rule_all_ports
}

# 고정 IP 주소 (옵션)
resource "google_compute_global_address" "default" {
  count = var.create_static_ip && var.lb_type == "http" ? 1 : 0

  name    = var.static_ip_name
  project = var.project_id
}

# 리전 고정 IP 주소 (Internal LB용)
resource "google_compute_address" "internal" {
  count = var.create_static_ip && (var.lb_type == "internal" || var.lb_type == "internal_classic") ? 1 : 0

  name         = var.static_ip_name
  project      = var.project_id
  region       = var.region
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
}
