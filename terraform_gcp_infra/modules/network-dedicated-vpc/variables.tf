variable "project_id" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "routing_mode" {
  type    = string
  default = "GLOBAL"
}

variable "subnets" {
  type = map(object({
    region                = string
    cidr                  = string
    private_google_access = optional(bool, true)
    secondary_ranges = optional(list(object({
      name = string
      cidr = string
    })), [])
  }))
}

variable "nat_region" {
  type = string
}

variable "nat_min_ports_per_vm" {
  type    = number
  default = 1024
}

variable "nat_subnet_self_links" {
  description = "NAT 적용 대상 서브넷 self-link 목록 (비우면 모든 서브넷)"
  type        = list(string)
  default     = []
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

variable "enable_private_service_connection" {
  type    = bool
  default = true
}

variable "private_service_connection_prefix_length" {
  type    = number
  default = 24
}

variable "private_service_connection_name" {
  type    = string
  default = ""
}

variable "private_service_connection_existing_ranges" {
  type    = list(string)
  default = []
}

variable "private_service_connection_service" {
  type    = string
  default = "services/servicenetworking.googleapis.com"
}
