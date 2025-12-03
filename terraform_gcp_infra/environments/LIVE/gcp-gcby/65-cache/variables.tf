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
  default     = ""
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

variable "alternative_location_suffix" {
  type        = string
  description = "대체 존을 region에 접미사 형태로 지정하고 싶을 때 사용 (예: b => us-central1-b)"
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

variable "replica_count" {
  type        = number
  description = "Enterprise/Enterprise Plus 티어에서 읽기 복제본 수 (>=1일 때 Read Endpoint 제공)"
  default     = null
}

variable "shard_count" {
  type        = number
  description = "Enterprise Sharded 티어용 샤드 수"
  default     = null
}

variable "memory_size_gb" {
  type        = number
  description = "메모리 크기 (GB)"
  default     = 1
}

variable "redis_version" {
  type        = string
  description = "Redis 버전 (REDIS_3_2/4_0/5_0/6_X)"
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

variable "deletion_protection" {
  type        = bool
  description = "삭제 방지 활성화 (true: 삭제 방지, false: 삭제 허용)"
  default     = true
}

variable "enterprise_node_type" {
  type        = string
  description = "Enterprise 티어용 노드 타입 (예: REDIS_STANDARD_SMALL, REDIS_HIGHMEM_MEDIUM)"
  default     = "REDIS_STANDARD_SMALL"
}

variable "enterprise_authorization_mode" {
  type        = string
  description = "Enterprise 티어 인증 모드 (AUTH_MODE_IAM_AUTH, AUTH_MODE_DISABLED)"
  default     = "AUTH_MODE_DISABLED"
}

variable "enterprise_transit_encryption_mode" {
  type        = string
  description = "Enterprise 티어 전송 암호화 모드"
  default     = "TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"
}

variable "enterprise_redis_configs" {
  type        = map(string)
  description = "Enterprise 클러스터용 추가 Redis 설정"
  default     = {}
}

# =============================================================================
# Cross-Project PSC Connections (mgmt VPC 등 다른 프로젝트에서 접근 허용)
# =============================================================================
variable "enable_cross_project_psc" {
  type        = bool
  description = "Cross-project PSC 연결 활성화 (bootstrap 배포 후 true로 설정)"
  default     = false
}

variable "state_bucket" {
  type        = string
  description = "Terraform State 버킷 이름 (terraform_remote_state용)"
  default     = "delabs-terraform-state-live"
}

variable "mgmt_project_id" {
  type        = string
  description = "Management 프로젝트 ID (PSC Endpoint가 있는 프로젝트)"
  default     = "delabs-gcp-mgmt"
}

variable "mgmt_vpc_network" {
  type        = string
  description = "Management VPC Network URL"
  default     = "projects/delabs-gcp-mgmt/global/networks/delabs-gcp-mgmt-vpc"
}
