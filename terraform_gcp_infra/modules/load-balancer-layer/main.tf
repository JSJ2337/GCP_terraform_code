provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

module "naming" {
  source         = "../naming"
  project_name   = var.project_name
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

locals {
  network = length(trimspace(var.network)) > 0 ? var.network : (
    var.lb_type == "http" ? "" : "projects/${var.project_id}/global/networks/${module.naming.vpc_name}"
  )

  subnetwork = length(trimspace(var.internal_subnetwork_self_link)) > 0 ? var.internal_subnetwork_self_link : length(trimspace(var.subnetwork)) > 0 ? var.subnetwork : ""

  url_map_name = length(trimspace(var.url_map_name)) > 0 ? var.url_map_name : "${module.naming.backend_service_name}-url-map"

  target_http_proxy_name  = length(trimspace(var.target_http_proxy_name)) > 0 ? var.target_http_proxy_name : "${module.naming.forwarding_rule_name}-http-proxy"
  target_https_proxy_name = length(trimspace(var.target_https_proxy_name)) > 0 ? var.target_https_proxy_name : "${module.naming.forwarding_rule_name}-https-proxy"

  static_ip_name    = length(trimspace(var.static_ip_name)) > 0 ? var.static_ip_name : "${module.naming.forwarding_rule_name}-ip"
  health_check_name = length(trimspace(var.health_check_name)) > 0 ? var.health_check_name : module.naming.health_check_name

  auto_backends = [
    for name, link in var.auto_instance_groups : {
      group           = link
      balancing_mode  = var.auto_backend_balancing_mode
      capacity_scaler = var.auto_backend_capacity_scaler
      max_utilization = var.auto_backend_max_utilization
      description     = "auto-${name}"
    }
  ]

  effective_backends = concat(var.backends, local.auto_backends)
}

module "load_balancer" {
  source = "../load-balancer"

  project_id = var.project_id
  lb_type    = var.lb_type
  region     = var.region

  # Network (Internal LB용)
  network    = local.network
  subnetwork = local.subnetwork

  # Backend Service
  backend_service_name = length(trimspace(var.backend_service_name)) > 0 ? var.backend_service_name : module.naming.backend_service_name
  backend_protocol     = var.backend_protocol
  backend_port_name    = var.backend_port_name
  backend_timeout      = var.backend_timeout
  backends             = local.effective_backends

  # Session affinity
  session_affinity            = var.session_affinity
  affinity_cookie_ttl         = var.affinity_cookie_ttl
  connection_draining_timeout = var.connection_draining_timeout

  # Health Check
  create_health_check              = var.create_health_check
  health_check_name                = local.health_check_name
  health_check_type                = var.health_check_type
  health_check_port                = var.health_check_port
  health_check_request_path        = var.health_check_request_path
  health_check_response            = var.health_check_response
  health_check_port_specification  = var.health_check_port_specification
  health_check_timeout             = var.health_check_timeout
  health_check_interval            = var.health_check_interval
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_logging             = var.health_check_logging

  # CDN (HTTP(S) LB만 해당)
  enable_cdn            = var.enable_cdn
  cdn_cache_mode        = var.cdn_cache_mode
  cdn_default_ttl       = var.cdn_default_ttl
  cdn_max_ttl           = var.cdn_max_ttl
  cdn_client_ttl        = var.cdn_client_ttl
  cdn_negative_caching  = var.cdn_negative_caching
  cdn_serve_while_stale = var.cdn_serve_while_stale

  # IAP (HTTP(S) LB만 해당)
  enable_iap               = var.enable_iap
  iap_oauth2_client_id     = var.iap_oauth2_client_id
  iap_oauth2_client_secret = var.iap_oauth2_client_secret

  # Logging
  enable_logging      = var.enable_logging
  logging_sample_rate = var.logging_sample_rate

  # URL Map (HTTP(S) LB만 해당)
  url_map_name  = local.url_map_name
  host_rules    = var.host_rules
  path_matchers = var.path_matchers

  # SSL (HTTP(S) LB만 해당)
  use_ssl          = var.use_ssl
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy

  # Target Proxies (HTTP(S) LB만 해당)
  target_http_proxy_name  = local.target_http_proxy_name
  target_https_proxy_name = local.target_https_proxy_name

  # Forwarding Rule
  forwarding_rule_name      = length(trimspace(var.forwarding_rule_name)) > 0 ? var.forwarding_rule_name : module.naming.forwarding_rule_name
  forwarding_rule_ports     = var.forwarding_rule_ports
  forwarding_rule_all_ports = var.forwarding_rule_all_ports

  # Static IP
  create_static_ip  = var.create_static_ip
  static_ip_name    = local.static_ip_name
  static_ip_address = var.static_ip_address
}
