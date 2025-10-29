variable "project_id" {
  description = "관리용 프로젝트 ID"
  type        = string
}

variable "project_name" {
  description = "관리용 프로젝트 이름"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing Account ID"
  type        = string
}

variable "folder_id" {
  description = "Folder ID (선택사항)"
  type        = string
  default     = null
}

variable "labels" {
  description = "프로젝트 및 리소스 레이블"
  type        = map(string)
  default     = {}
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
