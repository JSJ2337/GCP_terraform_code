# =============================================================================
# 12-dns Variables
# =============================================================================

variable "management_project_id" {
  description = "관리용 프로젝트 ID"
  type        = string
}

variable "vpc_self_link" {
  description = "VPC Self Link (10-network에서 전달)"
  type        = string
}

variable "dns_zone_name" {
  description = "DNS Zone 리소스 이름"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.dns_zone_name))
    error_message = "DNS zone name must start with a letter, contain only lowercase letters, numbers, hyphens, and be max 63 characters."
  }
}

variable "dns_domain" {
  description = "DNS 도메인 (마지막에 . 포함)"
  type        = string

  validation {
    condition     = can(regex("\\.$", var.dns_domain))
    error_message = "DNS domain must end with a trailing dot (e.g., 'example.internal.')."
  }
}

variable "jenkins_internal_ip" {
  description = "Jenkins VM 내부 IP"
  type        = string

  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.jenkins_internal_ip))
    error_message = "jenkins_internal_ip must be a valid IPv4 address."
  }
}

variable "bastion_internal_ip" {
  description = "Bastion VM 내부 IP"
  type        = string

  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.bastion_internal_ip))
    error_message = "bastion_internal_ip must be a valid IPv4 address."
  }
}

variable "additional_dns_records" {
  description = "추가 DNS 레코드 맵"
  type = map(object({
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = {}
}

variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}
