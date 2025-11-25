# =============================================================================
# 50-compute Variables
# =============================================================================

# 프로젝트 정보 (00-foundation에서 전달)
variable "management_project_id" {
  description = "관리용 프로젝트 ID"
  type        = string
}

variable "jenkins_service_account_email" {
  description = "Jenkins SA 이메일"
  type        = string
}

# 네트워크 정보 (10-network에서 전달)
variable "vpc_self_link" {
  description = "VPC Self Link"
  type        = string
}

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

# Jenkins VM 설정
variable "jenkins_machine_type" {
  description = "Jenkins VM 머신 타입"
  type        = string
  default     = "e2-medium"
}

variable "jenkins_image" {
  description = "Jenkins VM OS 이미지"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "jenkins_disk_size" {
  description = "Jenkins VM 부트 디스크 크기 (GB)"
  type        = number
  default     = 50
}

variable "jenkins_startup_script" {
  description = "Jenkins VM 시작 스크립트 (커스텀)"
  type        = string
  default     = ""
}

# 네트워크 설정
variable "assign_external_ip" {
  description = "외부 IP 할당 여부"
  type        = bool
  default     = true
}

variable "create_static_ip" {
  description = "고정 외부 IP 생성 여부"
  type        = bool
  default     = false
}

# 추가 디스크 설정
variable "create_data_disk" {
  description = "Jenkins 데이터 디스크 생성 여부"
  type        = bool
  default     = false
}

variable "data_disk_size" {
  description = "데이터 디스크 크기 (GB)"
  type        = number
  default     = 100
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
