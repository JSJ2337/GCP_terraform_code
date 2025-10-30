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

# Naming conventions imported from parent locals.tf
# local.project_prefix is already defined in parent

module "load_balancer" {
  source = "../../../../modules/load-balancer"

  project_id = var.project_id
  lb_type    = var.lb_type
  region     = var.region

  # Network (Internal LB용)
  network    = var.network
  subnetwork = var.subnetwork

  # Backend Service
  backend_service_name = var.backend_service_name != "" ? var.backend_service_name : "${local.project_prefix}-backend"
  backend_protocol     = var.backend_protocol
  backend_port_name    = var.backend_port_name
  backend_timeout      = var.backend_timeout
  backends             = var.backends

  # Session affinity
  session_affinity            = var.session_affinity
  affinity_cookie_ttl         = var.affinity_cookie_ttl
  connection_draining_timeout = var.connection_draining_timeout

  # Health Check
  create_health_check                = var.create_health_check
  health_check_name                  = var.health_check_name != "" ? var.health_check_name : "${local.project_prefix}-health"
  health_check_type                  = var.health_check_type
  health_check_port                  = var.health_check_port
  health_check_request_path          = var.health_check_request_path
  health_check_response              = var.health_check_response
  health_check_port_specification    = var.health_check_port_specification
  health_check_timeout               = var.health_check_timeout
  health_check_interval              = var.health_check_interval
  health_check_healthy_threshold     = var.health_check_healthy_threshold
  health_check_unhealthy_threshold   = var.health_check_unhealthy_threshold
  health_check_logging               = var.health_check_logging

  # CDN (HTTP(S) LB만 해당)
  enable_cdn                = var.enable_cdn
  cdn_cache_mode            = var.cdn_cache_mode
  cdn_default_ttl           = var.cdn_default_ttl
  cdn_max_ttl               = var.cdn_max_ttl
  cdn_client_ttl            = var.cdn_client_ttl
  cdn_negative_caching      = var.cdn_negative_caching
  cdn_serve_while_stale     = var.cdn_serve_while_stale

  # IAP (HTTP(S) LB만 해당)
  enable_iap               = var.enable_iap
  iap_oauth2_client_id     = var.iap_oauth2_client_id
  iap_oauth2_client_secret = var.iap_oauth2_client_secret

  # Logging
  enable_logging       = var.enable_logging
  logging_sample_rate  = var.logging_sample_rate

  # URL Map (HTTP(S) LB만 해당)
  url_map_name   = var.url_map_name
  host_rules     = var.host_rules
  path_matchers  = var.path_matchers

  # SSL (HTTP(S) LB만 해당)
  use_ssl           = var.use_ssl
  ssl_certificates  = var.ssl_certificates
  ssl_policy        = var.ssl_policy

  # Target Proxies (HTTP(S) LB만 해당)
  target_http_proxy_name  = var.target_http_proxy_name
  target_https_proxy_name = var.target_https_proxy_name

  # Forwarding Rule
  forwarding_rule_name      = var.forwarding_rule_name != "" ? var.forwarding_rule_name : "${local.project_prefix}-lb"
  forwarding_rule_ports     = var.forwarding_rule_ports
  forwarding_rule_all_ports = var.forwarding_rule_all_ports

  # Static IP
  create_static_ip   = var.create_static_ip
  static_ip_name     = var.static_ip_name
  static_ip_address  = var.static_ip_address
}
