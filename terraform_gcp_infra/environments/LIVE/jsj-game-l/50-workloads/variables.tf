variable "project_id" {
  type = string
}

variable "project_name" {
  type        = string
  description = "Project name used for naming"
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "prod"
}

variable "organization" {
  type        = string
  description = "Organization prefix"
  default     = "myorg"
}

variable "region_primary" {
  type        = string
  description = "Primary region"
  default     = "us-central1"
}

variable "region_backup" {
  type        = string
  description = "Backup region"
  default     = "us-east1"
}

variable "region" {
  type        = string
  description = "Default GCP region for resources"
  default     = "us-central1"
}

variable "zone" {
  type    = string
  default = ""
}

variable "subnetwork_self_link" {
  type        = string
  description = "Count 방식 및 기본값으로 사용할 서브넷 self-link (instances map 사용 시 각 인스턴스에서 지정 가능)"
  default     = ""
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 1
}

variable "name_prefix" {
  type        = string
  description = "Prefix for instance names"
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "Machine type for instances"
  default     = "e2-micro"
}

variable "image_family" {
  type        = string
  description = "OS image family used to create the boot disk"
  default     = "debian-12"
}

variable "image_project" {
  type        = string
  description = "Project that hosts the image family"
  default     = "debian-cloud"
}

variable "boot_disk_size_gb" {
  type        = number
  description = "Boot disk size in GB"
  default     = 20
}

variable "boot_disk_type" {
  type        = string
  description = "Boot disk type (pd-standard, pd-balanced, pd-ssd, ...)"
  default     = "pd-balanced"
}

variable "enable_public_ip" {
  type        = bool
  description = "Whether to enable public IP for instances"
  default     = false
}

variable "enable_os_login" {
  type        = bool
  description = "Whether to enable OS Login"
  default     = true
}

variable "preemptible" {
  type        = bool
  description = "Whether instances should be preemptible"
  default     = false
}

variable "startup_script" {
  type        = string
  description = "Startup script for instances"
  default     = ""
}

variable "service_account_email" {
  type        = string
  description = "Service account email for instances"
  default     = ""
}

variable "service_account_scopes" {
  type        = list(string)
  description = "Scopes for the service account"
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "metadata" {
  type        = map(string)
  description = "Additional metadata applied to every instance"
  default     = {}
}

variable "tags" {
  type        = list(string)
  description = "Network tags for instances"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Labels for instances"
  default     = {}
}

# 새로운 for_each 방식 (권장)
variable "instances" {
  type = map(object({
    hostname              = optional(string)
    zone                  = optional(string)
    machine_type          = optional(string)
    subnetwork_self_link  = optional(string)
    enable_public_ip      = optional(bool)
    enable_os_login       = optional(bool)
    preemptible           = optional(bool)
    startup_script        = optional(string)
    startup_script_file   = optional(string)
    metadata              = optional(map(string))
    tags                  = optional(list(string))
    labels                = optional(map(string))
    boot_disk_size_gb     = optional(number)
    boot_disk_type        = optional(string)
    image_family          = optional(string)
    image_project         = optional(string)
    service_account_email = optional(string)
  }))
  default     = {}
  description = "VM 인스턴스 맵 (키=인스턴스명, 값=설정). 비워두면 instance_count 방식 사용"
}
