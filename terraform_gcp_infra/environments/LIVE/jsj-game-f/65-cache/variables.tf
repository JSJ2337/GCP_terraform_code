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
  description = "환경 값 (예: prod, stg)"
  default     = "prod"
}

variable "organization" {
  type        = string
  description = "조직/비즈니스 단위 접두어"
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
  description = "Memorystore 리전을 지정 (location_id)"
  default     = "us-central1"
}

variable "instance_name" {
  type        = string
  description = "명시적 Redis 인스턴스 이름 (비우면 naming 모듈 기반 자동 생성)"
  default     = ""
}

variable "alternative_location_id" {
  type        = string
  description = "Standard HA 티어용 대체 존 (예: us-central1-b)"
  default     = ""
}

variable "authorized_network" {
  type        = string
  description = "Memorystore에 접근 가능한 VPC self link (비우면 naming 모듈 기준 VPC 자동 사용)"
  default     = ""
}

variable "tier" {
  type        = string
  description = "Memorystore 티어 (STANDARD_HA, BASIC, 등)"
  default     = "STANDARD_HA"
}

variable "memory_size_gb" {
  type        = number
  description = "메모리 크기 (GB)"
  default     = 1
}

variable "redis_version" {
  type        = string
  description = "Redis 버전 (예: REDIS_6_X)"
  default     = "REDIS_6_X"
}

variable "connect_mode" {
  type        = string
  description = "연결 모드 (DIRECT_PEERING, PRIVATE_SERVICE_CONNECT)"
  default     = "DIRECT_PEERING"
}

variable "transit_encryption_mode" {
  type        = string
  description = "전송 암호화 옵션 (DISABLED, SERVER_AUTHENTICATION)"
  default     = "DISABLED"
}

variable "display_name" {
  type        = string
  description = "콘솔에 표시할 이름"
  default     = ""
}

variable "maintenance_window_day" {
  type        = string
  description = "주간 유지보수 요일 (예: MONDAY). 비우면 자동 설정."
  default     = ""
}

variable "maintenance_window_start_hour" {
  type        = number
  description = "유지보수 시작 시간 (0-23). 유지보수 요일을 지정할 때 필수."
  default     = null
}

variable "maintenance_window_start_minute" {
  type        = number
  description = "유지보수 시작 분 (0-59). 유지보수 요일을 지정할 때 필수."
  default     = null
}

variable "labels" {
  type        = map(string)
  description = "추가 라벨 (naming 모듈 공통 라벨과 병합됨)"
  default     = {}
}
