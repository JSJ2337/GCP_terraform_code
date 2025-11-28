# =============================================================================
# 20-storage Variables
# =============================================================================

variable "management_project_id" {
  description = "관리용 프로젝트 ID (00-foundation에서 전달)"
  type        = string
}

variable "jenkins_service_account_email" {
  description = "Jenkins SA 이메일 (00-foundation에서 전달)"
  type        = string
}

variable "bucket_name_prod" {
  description = "Production Terraform State 버킷 이름"
  type        = string
}

variable "bucket_name_dev" {
  description = "Development Terraform State 버킷 이름"
  type        = string
  default     = ""
}

variable "bucket_name_artifacts" {
  description = "아티팩트 버킷 이름"
  type        = string
  default     = ""
}

variable "bucket_location" {
  description = "버킷 위치"
  type        = string
  default     = "US"
}

variable "create_dev_bucket" {
  description = "Dev 환경용 버킷 생성 여부"
  type        = bool
  default     = false
}

variable "create_artifacts_bucket" {
  description = "아티팩트 버킷 생성 여부"
  type        = bool
  default     = false
}

variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}

variable "additional_jenkins_sa_emails" {
  description = "추가 Jenkins SA 이메일 목록 (다른 프로젝트의 Jenkins SA)"
  type        = list(string)
  default     = []
}
