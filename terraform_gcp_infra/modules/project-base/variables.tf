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

variable "billing_account" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "apis" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudkms.googleapis.com",
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

variable "cmek_key_id" {
  type    = string
  default = ""
}

variable "prevent_destroy" {
  type        = bool
  default     = false
  description = "프로젝트 삭제 방지 (true: 삭제 차단, false: 자유롭게 삭제 가능)"
}
