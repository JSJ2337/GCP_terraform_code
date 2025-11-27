variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = ""
}

variable "folder_id" {
  type    = string
  default = null
}

variable "org_id" {
  type    = string
  default = null
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to attach to the project"
}

variable "auto_grant_billing_permission" {
  type        = bool
  default     = false
  description = "자동으로 Terraform Service Account에 빌링 권한 부여 여부 (SA에 billing.admin 권한 필요)"
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "apis" {
  type = list(string)
  default = [
    # 핵심 API
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    # 네트워킹
    "servicenetworking.googleapis.com",
    # 관측/모니터링
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    # 스토리지/시크릿/KMS
    "storage.googleapis.com",
    "cloudkms.googleapis.com",
    # 워크로드 (옵션: 실제 사용 레이어에서 불필요 시 무시됨)
    "sqladmin.googleapis.com",      # Cloud SQL API
    "redis.googleapis.com"          # Memorystore API
  ]
}

variable "enable_budget" {
  type    = bool
  default = false
}

variable "budget_amount" {
  type    = number
  default = 100
}

variable "budget_currency" {
  type    = string
  default = "USD"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "manage_default_logging_bucket" {
  description = "기본 Cloud Logging 버킷(_Default)까지 Terraform으로 관리할지 여부 (API 전파 지연으로 실패하면 false 권장)"
  type        = bool
  default     = true
}

variable "logging_api_wait_duration" {
  description = "logging.googleapis.com 활성화 직후 기본 로그 버킷 구성을 시도하기 전에 대기할 시간 (예: \"60s\")"
  type        = string
  default     = "60s"
}

variable "cmek_key_id" {
  type    = string
  default = ""
}
