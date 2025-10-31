variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "region" {
  type        = string
  description = "인스턴스를 생성할 리전"
  default     = "us-central1"
}

variable "database_version" {
  type        = string
  description = "MySQL 버전"
  default     = "MYSQL_8_0"
}

variable "tier" {
  type        = string
  description = "머신 타입"
  default     = "db-n1-standard-1"
}

variable "availability_type" {
  type        = string
  description = "가용성 타입 (ZONAL 또는 REGIONAL)"
  default     = "ZONAL"
}

variable "disk_size" {
  type        = number
  description = "디스크 크기 (GB)"
  default     = 10
}

variable "disk_type" {
  type        = string
  description = "디스크 타입"
  default     = "PD_SSD"
}

variable "disk_autoresize" {
  type        = bool
  description = "디스크 자동 확장"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "삭제 보호"
  default     = true
}

variable "backup_enabled" {
  type        = bool
  description = "자동 백업 활성화"
  default     = true
}

variable "backup_start_time" {
  type        = string
  description = "백업 시작 시간"
  default     = "03:00"
}

variable "point_in_time_recovery_enabled" {
  type        = bool
  description = "Point-in-time 복구 활성화"
  default     = true
}

variable "transaction_log_retention_days" {
  type        = number
  description = "트랜잭션 로그 보존 기간"
  default     = 7
}

variable "backup_retained_count" {
  type        = number
  description = "보존할 백업 수"
  default     = 7
}

variable "ipv4_enabled" {
  type        = bool
  description = "공개 IP 활성화"
  default     = false
}

variable "private_network" {
  type        = string
  description = "VPC 네트워크 셀프 링크"
  default     = ""
}

# Note: require_ssl is deprecated in Google provider 7.x+
# variable "require_ssl" {
#   type        = bool
#   description = "SSL 연결 필수"
#   default     = true
# }

variable "authorized_networks" {
  type = list(object({
    name = string
    cidr = string
  }))
  description = "공개 IP 접근 허용 네트워크"
  default     = []
}

variable "maintenance_window_day" {
  type        = number
  description = "유지보수 요일"
  default     = 7
}

variable "maintenance_window_hour" {
  type        = number
  description = "유지보수 시작 시간"
  default     = 3
}

variable "maintenance_window_update_track" {
  type        = string
  description = "업데이트 트랙"
  default     = "stable"
}

variable "database_flags" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "데이터베이스 플래그"
  default     = []
}

variable "query_insights_enabled" {
  type        = bool
  description = "쿼리 인사이트 활성화"
  default     = true
}

variable "query_string_length" {
  type        = number
  description = "쿼리 인사이트 문자열 길이"
  default     = 1024
}

variable "record_application_tags" {
  type        = bool
  description = "애플리케이션 태그 기록"
  default     = false
}

variable "enable_slow_query_log" {
  type        = bool
  description = "느린 쿼리 로깅 활성화"
  default     = true
}

variable "slow_query_log_time" {
  type        = number
  description = "느린 쿼리 기준 시간 (초)"
  default     = 2
}

variable "enable_general_log" {
  type        = bool
  description = "일반 쿼리 로깅 활성화"
  default     = false
}

variable "log_output" {
  type        = string
  description = "로그 출력 방식"
  default     = "FILE"
}

variable "databases" {
  type = list(object({
    name      = string
    charset   = optional(string)
    collation = optional(string)
  }))
  description = "생성할 데이터베이스 목록"
  default     = []
}

variable "users" {
  type = list(object({
    name     = string
    password = string
    host     = optional(string)
  }))
  description = "생성할 사용자 목록"
  default     = []
  # Note: Cannot use sensitive = true with for_each in Terraform
  # Passwords will still be marked as sensitive in state file
}

variable "read_replicas" {
  type = map(object({
    name            = string
    region          = string
    tier            = string
    failover_target = optional(bool)
  }))
  description = "읽기 복제본 설정"
  default     = {}
}

variable "labels" {
  type        = map(string)
  description = "리소스 레이블"
  default     = {}
}
