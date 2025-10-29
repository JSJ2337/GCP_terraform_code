terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

# Health Check
resource "google_compute_health_check" "default" {
  count = var.create_health_check ? 1 : 0

  name    = var.health_check_name
  project = var.project_id

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

# Backend Service - for HTTP(S) and Internal LB
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

  # Session affinity
  session_affinity = var.session_affinity
  affinity_cookie_ttl_sec = var.session_affinity == "GENERATED_COOKIE" ? var.affinity_cookie_ttl : null

  # Connection draining
  connection_draining_timeout_sec = var.connection_draining_timeout

  # CDN (HTTP(S) only)
  dynamic "cdn_policy" {
    for_each = var.lb_type == "http" && var.enable_cdn ? [1] : []
    content {
      cache_mode                   = var.cdn_cache_mode
      default_ttl                  = var.cdn_default_ttl
      max_ttl                      = var.cdn_max_ttl
      client_ttl                   = var.cdn_client_ttl
      negative_caching             = var.cdn_negative_caching
      serve_while_stale            = var.cdn_serve_while_stale
    }
  }

  # IAP (HTTP(S) only)
  dynamic "iap" {
    for_each = var.lb_type == "http" && var.enable_iap ? [1] : []
    content {
      oauth2_client_id     = var.iap_oauth2_client_id
      oauth2_client_secret = var.iap_oauth2_client_secret
    }
  }

  # Logging
  log_config {
    enable      = var.enable_logging
    sample_rate = var.logging_sample_rate
  }

  # Internal LB specific
  load_balancing_scheme = var.lb_type == "internal" ? "INTERNAL_MANAGED" : "EXTERNAL_MANAGED"
}

# Regional Backend Service - for Internal LB
resource "google_compute_region_backend_service" "internal" {
  count = var.lb_type == "internal_classic" ? 1 : 0

  name     = var.backend_service_name
  project  = var.project_id
  region   = var.region
  protocol = "TCP"

  health_checks = var.create_health_check ? [google_compute_health_check.default[0].id] : var.health_check_ids

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

# URL Map - for HTTP(S) LB
resource "google_compute_url_map" "default" {
  count = var.lb_type == "http" ? 1 : 0

  name            = var.url_map_name
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

# Target HTTP Proxy
resource "google_compute_target_http_proxy" "default" {
  count = var.lb_type == "http" && !var.use_ssl ? 1 : 0

  name    = var.target_http_proxy_name
  project = var.project_id
  url_map = google_compute_url_map.default[0].id
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "default" {
  count = var.lb_type == "http" && var.use_ssl ? 1 : 0

  name             = var.target_https_proxy_name
  project          = var.project_id
  url_map          = google_compute_url_map.default[0].id
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy
}

# Global Forwarding Rule - HTTP
resource "google_compute_global_forwarding_rule" "http" {
  count = var.lb_type == "http" && !var.use_ssl ? 1 : 0

  name       = var.forwarding_rule_name
  project    = var.project_id
  target     = google_compute_target_http_proxy.default[0].id
  port_range = "80"
  ip_address = var.static_ip_address

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Global Forwarding Rule - HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  count = var.lb_type == "http" && var.use_ssl ? 1 : 0

  name       = var.forwarding_rule_name
  project    = var.project_id
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = var.static_ip_address

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Regional Forwarding Rule - Internal LB
resource "google_compute_forwarding_rule" "internal" {
  count = var.lb_type == "internal" || var.lb_type == "internal_classic" ? 1 : 0

  name                  = var.forwarding_rule_name
  project               = var.project_id
  region                = var.region
  network               = var.network
  subnetwork            = var.subnetwork
  backend_service       = var.lb_type == "internal" ? google_compute_backend_service.default[0].id : google_compute_region_backend_service.internal[0].id
  load_balancing_scheme = var.lb_type == "internal" ? "INTERNAL_MANAGED" : "INTERNAL"
  ip_address            = var.static_ip_address
  ports                 = var.forwarding_rule_ports
  all_ports             = var.forwarding_rule_all_ports
}

# Static IP Address (optional)
resource "google_compute_global_address" "default" {
  count = var.create_static_ip && var.lb_type == "http" ? 1 : 0

  name    = var.static_ip_name
  project = var.project_id
}

# Regional Static IP Address (Internal LB)
resource "google_compute_address" "internal" {
  count = var.create_static_ip && (var.lb_type == "internal" || var.lb_type == "internal_classic") ? 1 : 0

  name         = var.static_ip_name
  project      = var.project_id
  region       = var.region
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
}
