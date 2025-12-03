variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnetwork_self_link" {
  type        = string
  description = "projects/<p>/regions/<r>/subnetworks/<name>"
}

# 기존 count 방식 (하위 호환성)
variable "instance_count" {
  type        = number
  default     = 0
  description = "인스턴스 개수 (instances가 비어있을 때만 사용)"
}

variable "name_prefix" {
  type    = string
  default = "gce-node"
}

# 새로운 for_each 방식 (권장)
variable "instances" {
  type = map(object({
    hostname              = optional(string)
    zone                  = optional(string)
    machine_type          = optional(string)
    subnetwork_self_link  = optional(string)
    network_ip            = optional(string)  # 고정 내부 IP 주소
    enable_public_ip      = optional(bool)
    enable_os_login       = optional(bool)
    preemptible           = optional(bool)
    startup_script        = optional(string)
    metadata              = optional(map(string))
    tags                  = optional(list(string))
    labels                = optional(map(string))
    boot_disk_size_gb     = optional(number)
    boot_disk_type        = optional(string)
    boot_disk_name        = optional(string)  # 부트 디스크 이름 (지정 안하면 {instance_name}-boot)
    image_family          = optional(string)
    image_project         = optional(string)
    service_account_email = optional(string)
  }))
  default     = {}
  description = "VM 인스턴스 맵 (키=인스턴스명, 값=설정). 비워두면 instance_count 방식 사용"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "image_family" {
  type    = string
  default = "debian-12"
}

variable "image_project" {
  type    = string
  default = "debian-cloud"
}

variable "boot_disk_size_gb" {
  type    = number
  default = 20
}

variable "boot_disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "enable_public_ip" {
  type    = bool
  default = false
}

variable "enable_os_login" {
  type    = bool
  default = true
}

variable "preemptible" {
  type        = bool
  default     = false
  description = "Spot(선점형) 인스턴스 사용"
}

variable "service_account_email" {
  type        = string
  default     = ""
  description = "비우면 기본 Compute Engine SA 사용"
}

variable "service_account_scopes" {
  type    = list(string)
  default = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "startup_script" {
  type        = string
  default     = ""
  description = "부팅 시 실행할 스크립트(공백이면 미설정)"
}

variable "metadata" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
