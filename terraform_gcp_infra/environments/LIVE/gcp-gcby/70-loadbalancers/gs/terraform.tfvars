lb_type           = "http"
# region은 terragrunt.hcl에서 자동으로 region_primary 주입
backend_protocol  = "HTTP"
backend_port_name = "http"
backend_timeout   = 30

backends = []

# Instance Groups 정의 (50-workloads의 VM을 그룹화)
instance_groups = {
  # Game Server (존별 분리)
  "gcby-gs-ig-a" = {
    instances   = ["gcby-gs01"]
    zone_suffix = "a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "gcby-gs-ig-b" = {
    instances   = ["gcby-gs02"]
    zone_suffix = "b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "gcby-gs-ig-c" = {
    instances   = ["gcby-gs03"]
    zone_suffix = "c"
    named_ports = [{ name = "http", port = 80 }]
  }
}

auto_backend_balancing_mode  = "UTILIZATION"
auto_backend_capacity_scaler = 1.0
auto_backend_max_utilization = 0.8

session_affinity            = "NONE"
affinity_cookie_ttl         = 0
connection_draining_timeout = 300

create_health_check              = true
health_check_type                = "http"
health_check_port                = 80
health_check_request_path        = "/"
health_check_response            = ""
health_check_port_specification  = "USE_FIXED_PORT"
health_check_timeout             = 5
health_check_interval            = 10
health_check_healthy_threshold   = 2
health_check_unhealthy_threshold = 2
health_check_logging             = false

enable_cdn          = false
enable_iap          = false
enable_logging      = true
logging_sample_rate = 1.0
