variable "project_id" {
  type = string
}

variable "enable_central_log_sink" {
  type    = bool
  default = false
}

variable "central_logging_project" {
  type    = string
  default = ""
}

variable "central_logging_bucket" {
  type    = string
  default = "_Default"
}

variable "log_filter" {
  type    = string
  default = ""
}

variable "dashboard_json_files" {
  type    = list(string)
  default = []
}

variable "notification_channels" {
  type        = list(string)
  description = "Alert 정책에 연결할 Notification Channel 리소스 이름 목록 (수동 생성된 채널)"
  default     = []
}

variable "enable_slack_notifications" {
  type        = bool
  description = "Slack Notification Channel 자동 생성 여부"
  default     = false
}

variable "slack_webhook_secret_name" {
  type        = string
  description = "Slack Webhook URL이 저장된 Secret Manager secret 이름"
  default     = "slack-webhook-url"
}

variable "slack_webhook_secret_project" {
  type        = string
  description = "Slack Webhook Secret이 저장된 프로젝트 ID (비어있으면 현재 프로젝트 사용)"
  default     = ""
}

variable "slack_channel_name" {
  type        = string
  description = "Slack 채널 이름 (예: #alerts, #monitoring)"
  default     = "#alerts"
}

variable "slack_channel_display_name" {
  type        = string
  description = "GCP Console에 표시될 Slack Notification Channel 이름"
  default     = "Slack Alerts"
}

variable "enable_vm_cpu_alert" {
  type        = bool
  description = "GCE VM CPU 사용률 Alert 생성 여부"
  default     = false
}

variable "vm_cpu_threshold" {
  type        = number
  description = "VM CPU 경고 임계값 (0~1)"
  default     = 0.8
}

variable "vm_cpu_duration" {
  type        = string
  description = "VM CPU 경고 조건 지속 시간 (예: 300s)"
  default     = "300s"
}

variable "vm_instance_filter_regex" {
  type        = string
  description = "모니터링 필터에 사용할 VM 인스턴스 이름 정규식 (monitoring.regex.full_match)"
  default     = ""
}

variable "enable_cloudsql_cpu_alert" {
  type        = bool
  description = "Cloud SQL CPU 사용률 Alert 생성 여부"
  default     = false
}

variable "cloudsql_cpu_threshold" {
  type        = number
  description = "Cloud SQL CPU 경고 임계값 (0~1)"
  default     = 0.75
}

variable "cloudsql_cpu_duration" {
  type        = string
  description = "Cloud SQL CPU 경고 조건 지속 시간"
  default     = "600s"
}

variable "cloudsql_instance_regex" {
  type        = string
  description = "Cloud SQL instance database_id 필터 정규식 (region 포함, monitoring.regex.full_match)"
  default     = ""
}

variable "enable_memorystore_memory_alert" {
  type        = bool
  description = "Memorystore Redis 메모리 사용률 Alert 생성 여부"
  default     = false
}

variable "memorystore_memory_threshold" {
  type        = number
  description = "Redis 메모리 사용률 경고 임계값 (0~1)"
  default     = 0.7
}

variable "memorystore_memory_duration" {
  type        = string
  description = "Redis 메모리 사용률 경고 조건 지속 시간"
  default     = "300s"
}

variable "memorystore_instance_regex" {
  type        = string
  description = "Redis instance_id 필터 정규식"
  default     = ""
}

variable "enable_lb_5xx_alert" {
  type        = bool
  description = "HTTP(S) Load Balancer 5xx 오류 Alert 생성 여부"
  default     = false
}

variable "lb_5xx_threshold" {
  type        = number
  description = "분당 5xx 요청 수 임계값"
  default     = 5
}

variable "lb_5xx_duration" {
  type        = string
  description = "5xx 오류 경고 조건 지속 시간"
  default     = "300s"
}

variable "lb_target_proxy_regex" {
  type        = string
  description = "Load balancer target proxy 이름 정규식"
  default     = ""
}
