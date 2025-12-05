lb_type           = "http"
# region은 terragrunt.hcl에서 자동으로 region_primary 주입
backend_protocol  = "HTTP"
backend_port_name = "http"
backend_timeout   = 30

backends = []

# Instance Groups 정의 (50-workloads의 VM을 그룹화)
# terragrunt.hcl에서 동적으로 이름이 생성됨:
#   - Instance Group 이름: {project_name}-{layer_name}-ig-{zone_suffix}
#   - VM 이름: {project_name}-{vm_key}
# 아래는 terraform.tfvars에서는 빈 맵으로 두고, terragrunt.hcl에서 주입
instance_groups = {}

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
