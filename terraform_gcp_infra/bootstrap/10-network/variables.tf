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
  description = "PSC Endpoints for Cloud SQL instances"
  type = map(object({
    region                    = string
    ip_address                = string
    target_service_attachment = string
    allow_global_access       = bool
  }))
  default = {}
}

variable "psc_cloudsql_ip" {
  description = "PSC endpoint IP for Cloud SQL"
  type        = string
  default     = "10.250.20.20"
}

variable "psc_redis_ip" {
  description = "PSC endpoint IP for Redis"
  type        = string
  default     = "10.250.20.101"
}

variable "gcby_vpc_network_url" {
  description = "VPC Peering 대상 네트워크 URL (gcby VPC)"
  type        = string
  default     = ""
}

variable "gcby_cloudsql_service_attachment" {
  description = "gcby Cloud SQL PSC Service Attachment (from dependency)"
  type        = string
  default     = ""
}

variable "gcby_redis_service_attachment" {
  description = "gcby Redis PSC Service Attachment (from dependency)"
  type        = string
  default     = ""
}
