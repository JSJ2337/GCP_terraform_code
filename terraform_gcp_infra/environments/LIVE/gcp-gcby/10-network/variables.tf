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
  description = "Default GCP region for resources"
  default     = "us-central1"
}

variable "routing_mode" {
  type        = string
  description = "VPC 라우팅 모드 (GLOBAL/REGIONAL)"
  default     = "GLOBAL"
}

variable "nat_min_ports_per_vm" {
  type        = number
  description = "Cloud NAT VM당 최소 포트 수"
  default     = 1024
}

variable "firewall_rules" {
  type = list(object({
    name           = string
    direction      = optional(string, "INGRESS")
    ranges         = optional(list(string))
    allow_protocol = optional(string, "tcp")
    allow_ports    = optional(list(string), [])
    priority       = optional(number, 1000)
    target_tags    = optional(list(string))
    disabled       = optional(bool, false)
    description    = optional(string)
  }))
  default = []
}

variable "enable_private_service_connection" {
  type        = bool
  description = "Private Service Connect(VPC Peering) 연결 생성 여부"
  default     = true
}

variable "private_service_connection_address" {
  type        = string
  description = "사설 서비스 연결용 예약 IP 범위 시작 주소 (예: 10.10.12.0)"
  default     = ""
}

variable "private_service_connection_prefix_length" {
  type        = number
  description = "사설 서비스 연결용 예약 IP 범위 prefix 길이"
  default     = 24
}

variable "private_service_connection_name" {
  type        = string
  description = "사설 서비스 연결용 Global Address 이름 (비워두면 자동 생성)"
  default     = ""
}

variable "additional_subnets" {
  description = "추가로 생성할 서브넷 목록 (DMZ, Private/WAS, DB 등 역할 기반 서브넷)"
  type = list(object({
    name                  = optional(string)
    region                = optional(string)
    cidr                  = string
    private_google_access = optional(bool, true)
    secondary_ranges = optional(list(object({
      name = string
      cidr = string
    })), [])
  }))
  default = []
}

variable "dmz_subnet_name" {
  type        = string
  description = "additional_subnets에 선언된 DMZ(외부 노출) 서브넷 이름"
  default     = ""
}

variable "private_subnet_name" {
  type        = string
  description = "additional_subnets에 선언된 내부(Private/WAS) 서브넷 이름"
  default     = ""
}

variable "db_subnet_name" {
  type        = string
  description = "additional_subnets에 선언된 DB 서브넷 이름"
  default     = ""
}

variable "enable_memorystore_psc_policy" {
  type        = bool
  description = "Memorystore Enterprise용 Service Connection Policy 생성 여부"
  default     = false
}

variable "memorystore_psc_region" {
  type        = string
  description = "PSC 정책을 생성할 리전 (비워두면 region_primary 사용)"
  default     = ""
}

variable "memorystore_psc_subnet_name" {
  type        = string
  description = "PSC에서 IP를 할당할 서브넷 이름 (기본: private_subnet_name)"
  default     = ""
}

variable "memorystore_psc_policy_name" {
  type        = string
  description = "Service Connection Policy 이름 (비워두면 자동 생성)"
  default     = ""
}

variable "memorystore_psc_connection_limit" {
  type        = number
  description = "PSC 서비스 연결 정책에서 허용할 최대 연결 수"
  default     = 4
}

variable "enable_cloudsql_psc_policy" {
  type        = bool
  description = "Cloud SQL용 Service Connection Policy 생성 여부"
  default     = false
}

variable "cloudsql_psc_region" {
  type        = string
  description = "Cloud SQL PSC 정책을 생성할 리전 (비워두면 region_primary 사용)"
  default     = ""
}

variable "cloudsql_psc_subnet_name" {
  type        = string
  description = "Cloud SQL PSC에서 IP를 할당할 서브넷 이름 (기본: private_subnet_name)"
  default     = ""
}

variable "cloudsql_psc_policy_name" {
  type        = string
  description = "Cloud SQL Service Connection Policy 이름 (비워두면 자동 생성)"
  default     = ""
}

variable "cloudsql_psc_connection_limit" {
  type        = number
  description = "Cloud SQL PSC 서비스 연결 정책에서 허용할 최대 연결 수"
  default     = 5
}

variable "cloudsql_service_attachment" {
  description = "Cloud SQL PSC Service Attachment (from dependency)"
  type        = string
  default     = ""
}

variable "redis_service_attachments" {
  description = "Redis PSC Service Attachments list (Discovery + Shard from dependency)"
  type        = list(string)
  default     = []
}

variable "psc_cloudsql_ip" {
  description = "PSC endpoint IP for Cloud SQL"
  type        = string
  default     = "10.10.12.51"
}

variable "psc_redis_ips" {
  description = "PSC endpoint IPs for Redis (Discovery + Shard)"
  type        = list(string)
  default     = ["10.10.12.101", "10.10.12.102"]
}

variable "peer_network_url" {
  description = "VPC Peering 대상 네트워크 URL (common.naming.tfvars에서 전달)"
  type        = string
  default     = ""
}
