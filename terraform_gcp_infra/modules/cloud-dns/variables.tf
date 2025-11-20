variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "zone_name" {
  type        = string
  description = "DNS Managed Zone 이름 (GCP 리소스명, 영숫자와 하이픈만 사용)"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.zone_name))
    error_message = "zone_name은 소문자, 숫자, 하이픈만 포함해야 합니다."
  }
}

variable "dns_name" {
  type        = string
  description = "DNS 도메인 이름 (반드시 마침표로 끝나야 함, 예: example.com.)"

  validation {
    condition     = can(regex("\\.$", var.dns_name))
    error_message = "dns_name은 반드시 마침표(.)로 끝나야 합니다."
  }
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

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility는 'public' 또는 'private'만 가능합니다."
  }
}

variable "private_networks" {
  type        = list(string)
  description = "Private Zone이 접근 가능한 VPC 네트워크 self-link 목록"
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
  description = "DNSSEC 키 사양 (기본값: RSASHA256, 2048bit ZSK/KSK)"
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
  description = "Forwarding 대상 DNS 서버 목록 (Private Zone에서 외부 DNS로 쿼리 전달)"
  default     = []
}

variable "peering_network" {
  type        = string
  description = "Peering할 VPC 네트워크 self-link (다른 VPC의 DNS Zone과 연결)"
  default     = ""
}

variable "reverse_lookup" {
  type        = bool
  description = "Reverse lookup (PTR records) 활성화 여부"
  default     = false
}

variable "labels" {
  type        = map(string)
  description = "Managed Zone에 적용할 라벨"
  default     = {}
}

variable "dns_records" {
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number)
    rrdatas = list(string)
  }))
  description = "생성할 DNS 레코드 목록 (name, type, ttl, rrdatas)"
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
  description = "Inbound DNS forwarding 활성화 (외부에서 VPC DNS로 쿼리 가능)"
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
