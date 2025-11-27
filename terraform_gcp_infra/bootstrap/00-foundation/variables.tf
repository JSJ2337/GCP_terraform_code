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

variable "create_project" {
  description = "프로젝트를 새로 생성할지 여부 (false면 기존 프로젝트 참조)"
  type        = bool
  default     = false
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

variable "product_regions" {
  description = "게임별 리전 매핑 (layer.hcl에서 관리)"
  type        = map(list(string))
  default     = {}
  # 예시:
  # {
  #   "gcb-ygg"  = ["us-west1"]
  #   "gcp-gcby" = ["us-west1"]
  # }
}

variable "environments" {
  description = "환경 목록 (모든 게임/리전에서 동일)"
  type        = list(string)
  default     = ["LIVE", "Staging", "GQ-dev"]
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

variable "iap_tunnel_members" {
  description = "IAP 터널 접근 권한을 부여할 멤버 목록 (user:, group:, serviceAccount: 형식)"
  type        = set(string)
  default     = []
}

variable "os_login_admins" {
  description = "OS Login 관리자 권한을 부여할 멤버 목록 (sudo 권한)"
  type        = set(string)
  default     = []
}

variable "os_login_users" {
  description = "OS Login 일반 사용자 권한을 부여할 멤버 목록"
  type        = set(string)
  default     = []
}
