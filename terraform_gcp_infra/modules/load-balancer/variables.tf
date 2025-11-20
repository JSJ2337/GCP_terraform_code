variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "lb_type" {
  type        = string
  description = "로드 밸런서 타입 (http, internal, internal_classic)"
  validation {
    condition     = contains(["http", "internal", "internal_classic"], var.lb_type)
    error_message = "lb_type은 http, internal, internal_classic 중 하나여야 합니다."
  }
}

variable "region" {
  type        = string
  description = "리전 (Internal LB용)"
  default     = "us-central1"
}

variable "network" {
  type        = string
  description = "VPC 네트워크 (Internal LB용)"
  default     = ""
}

variable "subnetwork" {
  type        = string
  description = "서브넷 (Internal LB용)"
  default     = ""
}

# 헬스 체크
variable "create_health_check" {
  type        = bool
  description = "헬스 체크 생성 여부"
  default     = true
}

variable "health_check_name" {
  type        = string
  description = "헬스 체크 이름"
  default     = ""
}

variable "health_check_type" {
  type        = string
  description = "헬스 체크 타입 (http, https, tcp)"
  default     = "http"
}

variable "health_check_port" {
  type        = number
  description = "헬스 체크 포트"
  default     = 80
}

variable "health_check_request_path" {
  type        = string
  description = "헬스 체크 경로"
  default     = "/"
}

variable "health_check_response" {
  type        = string
  description = "헬스 체크 예상 응답"
  default     = ""
}

variable "health_check_port_specification" {
  type        = string
  description = "포트 지정 방식 (USE_FIXED_PORT, USE_NAMED_PORT, USE_SERVING_PORT)"
  default     = "USE_FIXED_PORT"
}

variable "health_check_timeout" {
  type        = number
  description = "헬스 체크 타임아웃 (초)"
  default     = 5
}

variable "health_check_interval" {
  type        = number
  description = "헬스 체크 간격 (초)"
  default     = 10
}

variable "health_check_healthy_threshold" {
  type        = number
  description = "정상 판정 임계값"
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  type        = number
  description = "비정상 판정 임계값"
  default     = 2
}

variable "health_check_logging" {
  type        = bool
  description = "헬스 체크 로깅 활성화"
  default     = false
}

variable "health_check_ids" {
  type        = list(string)
  description = "기존 헬스 체크 ID (create_health_check=false일 때)"
  default     = []
}

# 백엔드 서비스
variable "backend_service_name" {
  type        = string
  description = "백엔드 서비스 이름"
}

variable "backend_protocol" {
  type        = string
  description = "백엔드 프로토콜 (HTTP, HTTPS, HTTP2)"
  default     = "HTTP"
}

variable "backend_port_name" {
  type        = string
  description = "백엔드 포트 이름"
  default     = "http"
}

variable "backend_timeout" {
  type        = number
  description = "백엔드 타임아웃 (초)"
  default     = 30
}

variable "backends" {
  type = list(object({
    group           = string
    balancing_mode  = optional(string)
    capacity_scaler = optional(number)
    description     = optional(string)
    max_utilization = optional(number)
  }))
  description = "백엔드 그룹 목록"
  default     = []
}

variable "session_affinity" {
  type        = string
  description = "세션 친화성 (NONE, CLIENT_IP, GENERATED_COOKIE 등)"
  default     = "NONE"
}

variable "affinity_cookie_ttl" {
  type        = number
  description = "친화성 쿠키 TTL (초)"
  default     = 0
}

variable "connection_draining_timeout" {
  type        = number
  description = "연결 드레이닝 타임아웃 (초)"
  default     = 300
}

# CDN 설정
variable "enable_cdn" {
  type        = bool
  description = "Cloud CDN 활성화"
  default     = false
}

variable "cdn_cache_mode" {
  type        = string
  description = "CDN 캐시 모드"
  default     = "CACHE_ALL_STATIC"
}

variable "cdn_default_ttl" {
  type        = number
  description = "CDN 기본 TTL (초)"
  default     = 3600
}

variable "cdn_max_ttl" {
  type        = number
  description = "CDN 최대 TTL (초)"
  default     = 86400
}

variable "cdn_client_ttl" {
  type        = number
  description = "CDN 클라이언트 TTL (초)"
  default     = 3600
}

variable "cdn_negative_caching" {
  type        = bool
  description = "네거티브 캐싱 활성화"
  default     = false
}

variable "cdn_serve_while_stale" {
  type        = number
  description = "stale 콘텐츠 제공 시간 (초)"
  default     = 0
}

# IAP
variable "enable_iap" {
  type        = bool
  description = "Identity-Aware Proxy 활성화"
  default     = false
}

variable "iap_oauth2_client_id" {
  type        = string
  description = "IAP OAuth2 클라이언트 ID"
  default     = ""
  sensitive   = true
}

variable "iap_oauth2_client_secret" {
  type        = string
  description = "IAP OAuth2 클라이언트 시크릿"
  default     = ""
  sensitive   = true
}

# 로깅
variable "enable_logging" {
  type        = bool
  description = "로깅 활성화"
  default     = true
}

variable "logging_sample_rate" {
  type        = number
  description = "로깅 샘플링 비율 (0.0-1.0)"
  default     = 1.0
}

# URL 맵 (HTTP(S) LB)
variable "url_map_name" {
  type        = string
  description = "URL 맵 이름"
  default     = ""
}

variable "host_rules" {
  type = list(object({
    hosts        = list(string)
    path_matcher = string
  }))
  description = "호스트 규칙"
  default     = []
}

variable "path_matchers" {
  type = list(object({
    name            = string
    default_service = string
    path_rules = optional(list(object({
      paths   = list(string)
      service = string
    })))
  }))
  description = "경로 매처"
  default     = []
}

# SSL 설정
variable "use_ssl" {
  type        = bool
  description = "SSL/HTTPS 사용"
  default     = false
}

variable "ssl_certificates" {
  type        = list(string)
  description = "SSL 인증서 ID 목록"
  default     = []
}

variable "ssl_policy" {
  type        = string
  description = "SSL 정책"
  default     = ""
}

# 대상 프록시
variable "target_http_proxy_name" {
  type        = string
  description = "HTTP 프록시 이름"
  default     = ""
}

variable "target_https_proxy_name" {
  type        = string
  description = "HTTPS 프록시 이름"
  default     = ""
}

# 포워딩 규칙
variable "forwarding_rule_name" {
  type        = string
  description = "포워딩 규칙 이름"
}

variable "forwarding_rule_ports" {
  type        = list(string)
  description = "포워딩 규칙 포트 (Internal LB)"
  default     = []
}

variable "forwarding_rule_all_ports" {
  type        = bool
  description = "모든 포트 포워딩 (Internal LB)"
  default     = false
}

# 고정 IP
variable "create_static_ip" {
  type        = bool
  description = "고정 IP 생성"
  default     = false
}

variable "static_ip_name" {
  type        = string
  description = "고정 IP 이름"
  default     = ""
}

variable "static_ip_address" {
  type        = string
  description = "사용할 고정 IP 주소"
  default     = ""
}
