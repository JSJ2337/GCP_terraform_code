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
  default     = "live"
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

variable "zone_name" {
  type        = string
  description = "DNS Managed Zone 이름 (비우면 자동 생성)"
  default     = ""
}

variable "dns_name" {
  type        = string
  description = "DNS 도메인 이름 (반드시 마침표로 끝나야 함, 예: example.com.)"
}

variable "description" {
  type        = string
  description = "Managed Zone 설명"
  default     = ""
}

variable "visibility" {
  type        = string
  description = "DNS Zone 가시성 (public 또는 private)"
  default     = "public"
}

variable "private_networks" {
  type        = list(string)
  description = "Private Zone이 접근 가능한 VPC 네트워크 self-link 목록 (비우면 naming 모듈의 VPC 사용)"
  default     = []
}

variable "enable_dnssec" {
  type        = bool
  description = "DNSSEC 활성화 여부 (Public Zone에서만 사용 가능)"
  default     = false
}

variable "dnssec_key_specs" {
  type = list(object({
    algorithm  = string
    key_length = number
    key_type   = string
  }))
  description = "DNSSEC 키 사양"
  default = [
    {
      algorithm  = "rsasha256"
      key_length = 2048
      key_type   = "keySigning"
    },
    {
      algorithm  = "rsasha256"
      key_length = 2048
      key_type   = "zoneSigning"
    }
  ]
}

variable "target_name_servers" {
  type = list(object({
    ipv4_address    = string
    forwarding_path = optional(string)
  }))
  description = "Forwarding 대상 DNS 서버 목록"
  default     = []
}

variable "peering_network" {
  type        = string
  description = "Peering할 VPC 네트워크 self-link"
  default     = ""
}

variable "labels" {
  type        = map(string)
  description = "추가 라벨 (naming 모듈 공통 라벨과 병합됨)"
  default     = {}
}

variable "dns_records" {
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number)
    rrdatas = list(string)
  }))
  description = "생성할 DNS 레코드 목록"
  default     = []
}

variable "create_dns_policy" {
  type        = bool
  description = "DNS Policy 생성 여부"
  default     = false
}

variable "dns_policy_name" {
  type        = string
  description = "DNS Policy 이름"
  default     = ""
}

variable "dns_policy_description" {
  type        = string
  description = "DNS Policy 설명"
  default     = ""
}

variable "enable_inbound_forwarding" {
  type        = bool
  description = "Inbound DNS forwarding 활성화"
  default     = false
}

variable "enable_dns_logging" {
  type        = bool
  description = "DNS 쿼리 로깅 활성화"
  default     = false
}

variable "alternative_name_servers" {
  type = list(object({
    ipv4_address    = string
    forwarding_path = optional(string)
  }))
  description = "DNS Policy의 대체 네임서버 목록"
  default     = []
}

variable "dns_policy_networks" {
  type        = list(string)
  description = "DNS Policy가 적용될 VPC 네트워크 self-link 목록"
  default     = []
}
