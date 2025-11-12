variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "machine_type" {
  type        = string
  description = "기본 머신 타입"
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  type        = number
  description = "기본 부팅 디스크 크기(GB)"
  default     = 30
}

variable "boot_disk_type" {
  type        = string
  description = "기본 부팅 디스크 타입 (pd-balanced, pd-ssd 등)"
  default     = "pd-balanced"
}

variable "image_family" {
  type        = string
  description = "기본 이미지 패밀리"
  default     = "debian-12"
}

variable "image_project" {
  type        = string
  description = "기본 이미지 프로젝트"
  default     = "debian-cloud"
}

variable "startup_script" {
  type        = string
  description = "기본 startup_script (빈 문자열이면 비활성)"
  default     = ""
}

variable "metadata" {
  type        = map(string)
  description = "공통 메타데이터"
  default     = {}
}

variable "tags" {
  type        = list(string)
  description = "공통 네트워크 태그"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "공통 라벨"
  default     = {}
}

variable "service_account_email" {
  type        = string
  description = "기본 서비스 계정 이메일"
  default     = ""
}

variable "service_account_scopes" {
  type        = list(string)
  description = "서비스 계정 스코프"
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "groups" {
  description = "MIG 구성 맵"
  type = map(object({
    zone                  = optional(string)
    target_size           = number
    machine_type          = optional(string)
    subnetwork_self_link  = string
    enable_public_ip      = optional(bool)
    startup_script        = optional(string)
    metadata              = optional(map(string))
    tags                  = optional(list(string))
    labels                = optional(map(string))
    boot_disk_size_gb     = optional(number)
    boot_disk_type        = optional(string)
    image_family          = optional(string)
    image_project         = optional(string)
    service_account_email = optional(string)
    named_ports = optional(list(object({
      name = string
      port = number
    })))
  }))
  default = {}
}
