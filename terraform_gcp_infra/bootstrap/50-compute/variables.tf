# =============================================================================
# 50-compute Variables (gce-vmset 모듈과 동일한 형식)
# =============================================================================

# 프로젝트 정보 (00-foundation에서 전달)
variable "management_project_id" {
  description = "관리용 프로젝트 ID"
  type        = string
}

# 네트워크 정보 (10-network에서 전달)
variable "subnet_self_link" {
  description = "Subnet Self Link"
  type        = string
}

# 리전/존
variable "region_primary" {
  description = "기본 리전"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "VM이 생성될 존"
  type        = string
  default     = "asia-northeast3-a"
}

# =============================================================================
# 인스턴스 맵 (for_each 방식) - gce-vmset 모듈과 동일
# =============================================================================
variable "instances" {
  type = map(object({
    hostname              = optional(string)
    zone                  = optional(string)
    machine_type          = optional(string)
    enable_public_ip      = optional(bool)
    enable_os_login       = optional(bool)
    preemptible           = optional(bool)
    startup_script        = optional(string)
    metadata              = optional(map(string))
    tags                  = optional(list(string))
    labels                = optional(map(string))
    boot_disk_size_gb     = optional(number)
    boot_disk_type        = optional(string)
    image_family          = optional(string)
    image_project         = optional(string)
    service_account_email = optional(string)
    deletion_protection   = optional(bool)
  }))
  default     = {}
  description = "VM 인스턴스 맵 (키=인스턴스명, 값=설정)"
}

# =============================================================================
# 기본값 (instances에서 지정하지 않은 경우 사용)
# =============================================================================
variable "machine_type" {
  description = "VM 머신 타입"
  type        = string
  default     = "e2-custom-4-8192"  # 4 vCPU, 8GB (커스텀)
}

# 이미지 설정
variable "image_family" {
  description = "OS 이미지 패밀리"
  type        = string
  default     = "rocky-linux-10-optimized-gcp"
}

variable "image_project" {
  description = "OS 이미지 프로젝트"
  type        = string
  default     = "rocky-linux-cloud"
}

# 디스크 설정
variable "boot_disk_size_gb" {
  description = "부트 디스크 크기 (GB)"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "부트 디스크 타입"
  type        = string
  default     = "pd-ssd"
}

variable "data_disk_size_gb" {
  description = "데이터 디스크 크기 (GB) - 0이면 생성하지 않음"
  type        = number
  default     = 0
}

# 네트워크 설정
variable "enable_public_ip" {
  description = "외부 IP 할당 여부"
  type        = bool
  default     = true
}

variable "create_static_ip" {
  description = "고정 외부 IP 생성 여부"
  type        = bool
  default     = false
}

variable "tags" {
  description = "네트워크 태그"
  type        = list(string)
  default     = ["jenkins", "allow-ssh", "allow-internal"]
}

# OS 설정
variable "enable_os_login" {
  description = "OS Login 활성화"
  type        = bool
  default     = true
}

variable "preemptible" {
  description = "Spot(선점형) 인스턴스 사용"
  type        = bool
  default     = false
}

# Service Account
variable "service_account_email" {
  description = "VM에 연결할 Service Account 이메일 (비우면 기본 SA 사용)"
  type        = string
  default     = ""
}

variable "service_account_scopes" {
  description = "Service Account 스코프"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

# 스크립트
variable "startup_script" {
  description = "커스텀 시작 스크립트 (비우면 기본 스크립트 사용)"
  type        = string
  default     = ""
}

variable "metadata" {
  description = "추가 메타데이터"
  type        = map(string)
  default     = {}
}

# 보안 설정
variable "deletion_protection" {
  description = "VM 삭제 방지 활성화"
  type        = bool
  default     = true
}

# 레이블
variable "labels" {
  description = "리소스 레이블"
  type        = map(string)
  default     = {}
}
