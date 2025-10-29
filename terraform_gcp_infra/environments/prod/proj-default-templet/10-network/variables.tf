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
