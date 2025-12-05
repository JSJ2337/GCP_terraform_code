variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "project_name" {
  type        = string
  description = "프로젝트 명 (네이밍 규칙에 사용)"
}

variable "environment" {
  type        = string
  description = "환경 값"
  default     = "prod"
}

variable "organization" {
  type        = string
  description = "조직 접두어"
  default     = "myorg"
}

variable "region_primary" {
  type        = string
  description = "Primary 리전"
  default     = "us-central1"
}

variable "region_backup" {
  type        = string
  description = "Backup 리전"
  default     = "us-east1"
}

variable "region" {
  type        = string
  description = "인스턴스를 생성할 리전 (비워두면 Terragrunt region_primary 사용)"
  default     = ""
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

variable "edition" {
  type        = string
  description = "Cloud SQL Edition (ENTERPRISE, ENTERPRISE_PLUS)"
  default     = "ENTERPRISE"
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

variable "binary_log_enabled" {
  type        = bool
  description = "Binary 로그 활성화 (MySQL의 Point-in-time 복구용)"
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
  description = "VPC 네트워크 셀프 링크 (VPC Peering 방식)"
  default     = ""
}

variable "enable_psc" {
  type        = bool
  description = "Private Service Connect 활성화 (true: PSC Endpoint, false: VPC Peering)"
  default     = false
}

variable "psc_allowed_consumer_projects" {
  type        = list(string)
  description = "PSC 엔드포인트 생성을 허용할 프로젝트 ID 목록 (자기 프로젝트 + mgmt 프로젝트 등)"
  default     = []
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
    name            = optional(string)
    region          = optional(string)
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
  description = "읽기 복제본 설정 (이름/리전 미입력 시 자동으로 기본값 적용)"
  default     = {}
}

variable "labels" {
  type        = map(string)
  description = "리소스 레이블"
  default     = {}
}

variable "db_suffix" {
  type        = string
  description = "DB 인스턴스 이름 suffix (예: gdb, ldb, mysql)"
  default     = "mysql"
}

variable "management_project_id" {
  type        = string
  description = "관리 프로젝트 ID (Cross-Project PSC 등에 사용)"
}

variable "db_root_password" {
  type        = string
  description = "Root 사용자 비밀번호 (TODO: Secret Manager로 관리)"
  sensitive   = true
  default     = "REDACTED_PASSWORD"
}

variable "db_app_password" {
  type        = string
  description = "Application 사용자 비밀번호 (TODO: Secret Manager로 관리)"
  sensitive   = true
  default     = "REDACTED_PASSWORD"
}
