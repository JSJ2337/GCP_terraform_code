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
  description = "관리용 Subnet CIDR"
  type        = string
  default     = "10.0.0.0/24"
}

variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}
