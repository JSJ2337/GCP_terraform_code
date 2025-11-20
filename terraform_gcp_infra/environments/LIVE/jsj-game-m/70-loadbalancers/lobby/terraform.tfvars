lb_type           = "http"
# region은 terragrunt.hcl에서 자동으로 region_primary 주입
backend_protocol  = "HTTP"
backend_port_name = "http"
backend_timeout   = 30

backend_service_name   = "game-m-lobby-backend"
url_map_name           = "game-m-lobby-url-map"
target_http_proxy_name = "game-m-lobby-http-proxy"
forwarding_rule_name   = "game-m-lobby-lb"
static_ip_name         = "game-m-lobby-ip"

backends = []

auto_backend_balancing_mode  = "UTILIZATION"
auto_backend_capacity_scaler = 1.0
auto_backend_max_utilization = 0.8

session_affinity            = "NONE"
affinity_cookie_ttl         = 0
connection_draining_timeout = 300

create_health_check              = true
health_check_name                = "game-m-lobby-health"
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
