variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "routing_mode" {
  type        = string
  description = "VPC 라우팅 모드 (GLOBAL/REGIONAL)"
  default     = "GLOBAL"
}

# Subnet CIDR blocks
variable "subnet_primary_cidr" {
  type        = string
  description = "Primary 리전 서브넷 CIDR"
  default     = "10.1.0.0/20"
}

variable "subnet_backup_cidr" {
  type        = string
  description = "Backup 리전 서브넷 CIDR"
  default     = "10.2.0.0/20"
}

variable "pods_cidr" {
  type        = string
  description = "GKE Pods용 Secondary IP 범위 CIDR"
  default     = "10.1.16.0/20"
}

variable "services_cidr" {
  type        = string
  description = "GKE Services용 Secondary IP 범위 CIDR"
  default     = "10.1.32.0/20"
}

variable "nat_min_ports_per_vm" {
  type        = number
  description = "Cloud NAT VM당 최소 포트 수"
  default     = 1024
}

variable "firewall_rules" {
  type = list(object({
    name           = string
    direction      = optional(string, "INGRESS")
    ranges         = optional(list(string))
    allow_protocol = optional(string, "tcp")
    allow_ports    = optional(list(string), [])
    priority       = optional(number, 1000)
    target_tags    = optional(list(string))
    disabled       = optional(bool, false)
    description    = optional(string)
  }))
  default = []
}
