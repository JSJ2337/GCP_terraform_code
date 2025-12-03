# =============================================================================
# 10-network Variables
# =============================================================================

variable "management_project_id" {
  description = "관리용 프로젝트 ID (00-foundation에서 전달)"
  type        = string
}

variable "region_primary" {
  description = "기본 리전"
  type        = string
  default     = "asia-northeast3"
}

variable "subnet_cidr" {
  description = "관리용 Subnet CIDR (asia-northeast3)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_cidr_us_west1" {
  description = "us-west1 Subnet CIDR (PSC Endpoint용)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}

variable "psc_endpoints" {
  description = "PSC Endpoints for all projects (동적으로 terragrunt에서 생성됨)"
  type = map(object({
    region                    = string
    ip_address                = string
    target_service_attachment = string
    allow_global_access       = bool
  }))
  default = {}
}

variable "project_vpc_network_urls" {
  description = "모든 프로젝트의 VPC Peering 대상 URL (동적으로 terragrunt에서 생성됨)"
  type        = map(string)
  default     = {}
}
