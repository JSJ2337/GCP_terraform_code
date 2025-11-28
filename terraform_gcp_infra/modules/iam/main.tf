terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

resource "google_project_iam_member" "members" {
  for_each = {
    for b in var.bindings : "${b.role}|${b.member}" => b
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

resource "google_service_account" "sas" {
  for_each = { for s in var.service_accounts : s.account_id => s if var.create_service_accounts }

  account_id   = each.value.account_id
  display_name = lookup(each.value, "display_name", each.value.account_id)
  description  = lookup(each.value, "description", null)
}

output "service_accounts" {
  value = { for k, v in google_service_account.sas : k => v.email }
}
