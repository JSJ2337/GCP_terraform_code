# =============================================================================
# 15-firewall Variables
# =============================================================================

variable "management_project_id" {
  description = "관리용 프로젝트 ID (00-foundation에서 전달)"
  type        = string
}

variable "vpc_name" {
  description = "VPC 이름 (10-network에서 전달)"
  type        = string
}

variable "vpc_self_link" {
  description = "VPC Self Link (10-network에서 전달)"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR (내부 통신 허용용)"
  type        = string
}

variable "jenkins_allowed_cidrs" {
  description = "Jenkins 접근 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 운영 시 제한 필요
}

variable "bastion_allowed_cidrs" {
  description = "Bastion SSH 접근 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 운영 시 제한 필요
}

variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}
