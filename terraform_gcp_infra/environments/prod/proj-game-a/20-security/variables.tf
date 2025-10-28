variable "project_id" {
  type = string
}

variable "bindings" {
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "create_service_accounts" {
  type    = bool
  default = false
}

variable "service_accounts" {
  type = list(object({
    account_id   = string
    display_name = optional(string)
    description  = optional(string)
  }))
  default = []
}
