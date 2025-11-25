# =============================================================================
# 00-foundation Variables
# =============================================================================

variable "organization_id" {
  description = "GCP 조직 ID"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing Account ID"
  type        = string
}

variable "management_project_id" {
  description = "관리용 프로젝트 ID"
  type        = string
}

variable "management_project_name" {
  description = "관리용 프로젝트 이름"
  type        = string
  default     = ""
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

variable "manage_folders" {
  description = "게임/리전/환경 폴더 구조를 Terraform으로 생성/관리할지 여부"
  type        = bool
  default     = false
}

variable "manage_org_iam" {
  description = "Terraform으로 조직 레벨 IAM 부여를 관리할지 여부"
  type        = bool
  default     = false
}

variable "enable_billing_account_binding" {
  description = "청구 계정에 Jenkins SA의 roles/billing.user를 Terraform으로 부여할지 여부"
  type        = bool
  default     = false
}
