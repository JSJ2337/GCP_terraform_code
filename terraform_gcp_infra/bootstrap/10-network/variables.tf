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

# =============================================================================
# Subnets 동적 생성 (for_each)
# layer.hcl에서 정의하고, 새 리전 추가 시 layer.hcl에만 추가하면 됨
# =============================================================================
variable "subnets" {
  description = "Subnet 정의 (for_each로 Subnet, Router, NAT 동적 생성)"
  type = map(object({
    region     = string
    cidr       = string
    is_primary = bool
  }))
  default = {
    primary = {
      region     = "asia-northeast3"
      cidr       = "10.250.10.0/24"
      is_primary = true
    }
  }
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
  description = "프로젝트별 PSC Endpoint IP 주소 (Redis는 2개의 Service Attachment 필요)"
  type = map(object({
    cloudsql = string
    redis    = list(string)  # Redis Cluster는 2개의 PSC IP 필요 (Discovery + Shard)
  }))
  default = {
    gcby = {
      cloudsql = "10.250.20.51"
      redis    = ["10.250.20.101", "10.250.20.102"]  # 2개의 PSC endpoint
    }
    # 새 프로젝트 추가 시:
    # abc = {
    #   cloudsql = "10.250.21.20"
    #   redis    = ["10.250.21.101", "10.250.21.102"]
    # }
  }
}

variable "projects" {
  description = "프로젝트별 설정 (common.hcl에서 전달)"
  type = map(object({
    project_id  = string
    environment = string
    vpc_name    = string
    network_url = string
    psc_ips = object({
      cloudsql = string
      redis    = list(string)
    })
    vm_ips        = map(string)
    database_path = string
    cache_path    = string
  }))
  default = {}
}
