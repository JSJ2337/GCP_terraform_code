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

variable "instance_count" {
  type    = number
  default = 4
}

variable "name_prefix" {
  type    = string
  default = "gce-node"
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
