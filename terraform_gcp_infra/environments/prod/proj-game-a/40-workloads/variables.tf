variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnetwork_self_link" {
  type = string
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for instance names"
}

variable "machine_type" {
  type        = string
  description = "Machine type for instances"
}

variable "enable_public_ip" {
  type        = bool
  description = "Whether to enable public IP for instances"
}

variable "enable_os_login" {
  type        = bool
  description = "Whether to enable OS Login"
}

variable "preemptible" {
  type        = bool
  description = "Whether instances should be preemptible"
}

variable "startup_script" {
  type        = string
  description = "Startup script for instances"
}

variable "service_account_email" {
  type        = string
  description = "Service account email for instances"
}

variable "service_account_scopes" {
  type        = list(string)
  description = "Scopes for the service account"
}

variable "tags" {
  type        = list(string)
  description = "Network tags for instances"
}

variable "labels" {
  type        = map(string)
  description = "Labels for instances"
}
