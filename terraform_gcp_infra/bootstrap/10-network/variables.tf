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

variable "project_vpc_network_urls" {
  description = "모든 프로젝트의 VPC Peering 대상 URL (동적으로 terragrunt에서 생성됨)"
  type        = map(string)
  default     = {}
}

# =============================================================================
# PSC Endpoints 관련 변수 (terraform_remote_state 방식)
# =============================================================================
variable "enable_psc_endpoints" {
  description = "PSC Endpoints 생성 여부 (gcp-gcby 등 프로젝트가 배포된 후 true로 설정)"
  type        = bool
  default     = false
}

variable "state_bucket" {
  description = "Terraform State 버킷 이름 (terraform_remote_state용)"
  type        = string
  default     = "delabs-terraform-state-live"
}

variable "project_psc_ips" {
  description = "프로젝트별 PSC Endpoint IP 주소"
  type = map(object({
    cloudsql = string
    redis    = string
  }))
  default = {
    gcby = {
      cloudsql = "10.250.20.20"
      redis    = "10.250.20.101"
    }
    # 새 프로젝트 추가 시:
    # abc = {
    #   cloudsql = "10.250.21.20"
    #   redis    = "10.250.21.101"
    # }
  }
}
