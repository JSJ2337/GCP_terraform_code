variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "instance_name" {
  type        = string
  description = "Cloud SQL 인스턴스 이름"
}

variable "database_version" {
  type        = string
  description = "MySQL 버전 (MYSQL_8_0, MYSQL_5_7 등)"
  default     = "MYSQL_8_0"
}

variable "region" {
  type        = string
  description = "인스턴스를 생성할 리전"
}

variable "tier" {
  type        = string
  description = "머신 타입 (db-f1-micro, db-n1-standard-1 등)"
  default     = "db-n1-standard-1"
}

variable "availability_type" {
  type        = string
  description = "가용성 타입 (ZONAL 또는 REGIONAL for HA)"
  default     = "ZONAL"
}

variable "disk_size" {
  type        = number
  description = "디스크 크기 (GB)"
  default     = 10
}

variable "disk_type" {
  type        = string
  description = "디스크 타입 (PD_SSD 또는 PD_HDD)"
  default     = "PD_SSD"
}

variable "disk_autoresize" {
  type        = bool
  description = "디스크 자동 확장 활성화"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "삭제 보호 (실수로 인한 삭제 방지)"
  default     = false
}

# Backup configuration
variable "backup_enabled" {
  type        = bool
  description = "자동 백업 활성화"
  default     = true
}

variable "backup_start_time" {
  type        = string
  description = "백업 시작 시간 (HH:MM 형식)"
  default     = "03:00"
}

variable "binary_log_enabled" {
  type        = bool
  description = "Binary 로그 활성화 (MySQL의 Point-in-time 복구용)"
  default     = true
}

variable "transaction_log_retention_days" {
  type        = number
  description = "트랜잭션 로그 보존 기간 (일)"
  default     = 7
}

variable "backup_retained_count" {
  type        = number
  description = "보존할 백업 수"
  default     = 7
}

# Network configuration
variable "ipv4_enabled" {
  type        = bool
  description = "공개 IP 활성화"
  default     = false
}

variable "private_network" {
  type        = string
  description = "VPC 네트워크 셀프 링크 (Private IP용)"
  default     = ""
}

# Note: require_ssl is deprecated in Google provider 7.x+
# Use SSL certificates and connection policies at client level instead
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

# Maintenance window
variable "maintenance_window_day" {
  type        = number
  description = "유지보수 요일 (1=월요일, 7=일요일)"
  default     = 7
}

variable "maintenance_window_hour" {
  type        = number
  description = "유지보수 시작 시간 (0-23)"
  default     = 3
}

variable "maintenance_window_update_track" {
  type        = string
  description = "업데이트 트랙 (stable 또는 canary)"
  default     = "stable"
}

# Database flags
variable "database_flags" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "데이터베이스 플래그"
  default     = []
}

# Insights
variable "query_insights_enabled" {
  type        = bool
  description = "쿼리 인사이트 활성화"
  default     = true
}

variable "query_string_length" {
  type        = number
  description = "쿼리 인사이트에 저장할 쿼리 문자열 길이"
  default     = 1024
}

variable "record_application_tags" {
  type        = bool
  description = "애플리케이션 태그 기록"
  default     = false
}

# Logging configuration
variable "enable_slow_query_log" {
  type        = bool
  description = "느린 쿼리 로깅 활성화 (성능 모니터링용)"
  default     = true
}

variable "slow_query_log_time" {
  type        = number
  description = "느린 쿼리 기준 시간 (초) - 이 시간보다 오래 걸리는 쿼리를 로깅"
  default     = 2
}

variable "enable_general_log" {
  type        = bool
  description = "일반 쿼리 로깅 활성화 (모든 쿼리 로깅, 프로덕션에서는 비권장)"
  default     = false
}

variable "log_output" {
  type        = string
  description = "로그 출력 방식 (FILE 또는 TABLE, Cloud Logging으로 전송하려면 FILE 사용)"
  default     = "FILE"
  validation {
    condition     = contains(["FILE", "TABLE"], var.log_output)
    error_message = "log_output은 FILE 또는 TABLE이어야 합니다."
  }
}

# Databases
variable "databases" {
  type = list(object({
    name      = string
    charset   = optional(string)
    collation = optional(string)
  }))
  description = "생성할 데이터베이스 목록"
  default     = []
}

# Users
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

# Read replicas
variable "read_replicas" {
  type = map(object({
    name            = string
    region          = string
    tier            = string
    failover_target = optional(bool)

    availability_type               = optional(string)
    disk_size                       = optional(number)
    disk_type                       = optional(string)
    disk_autoresize                 = optional(bool)
    ipv4_enabled                    = optional(bool)
    private_network                 = optional(string)
    database_flags                  = optional(list(object({ name = string, value = string })))
    maintenance_window_day          = optional(number)
    maintenance_window_hour         = optional(number)
    maintenance_window_update_track = optional(string)
    labels                          = optional(map(string))
  }))
  description = "읽기 복제본 설정 (지역/머신 타입/여분 설정 포함)"
  default     = {}
}

variable "labels" {
  type        = map(string)
  description = "리소스 레이블"
  default     = {}
}
