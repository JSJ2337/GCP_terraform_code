terraform {
  required_version = ">= 1.6"
  required_providers {
    google      = { source = "hashicorp/google", version = ">= 5.30" }
    google-beta = { source = "hashicorp/google-beta", version = ">= 5.30" }
    time        = { source = "hashicorp/time", version = ">= 0.9" }
  }
}

# Project parent resolution
locals {
  trimmed_folder_id = var.folder_id == null ? "" : trimspace(var.folder_id)
  trimmed_org_id    = var.org_id == null ? "" : trimspace(var.org_id)

  parent_folder_id = local.trimmed_folder_id != "" ? local.trimmed_folder_id : null
  parent_org_id    = local.trimmed_org_id != "" ? local.trimmed_org_id : null
}

# 0) 프로젝트 생성 (+ 폴더/결제 연결)
resource "google_project" "this" {
  project_id          = var.project_id
  name                = var.project_name != "" ? var.project_name : var.project_id
  folder_id           = local.parent_folder_id
  org_id              = local.parent_folder_id == null ? local.parent_org_id : null
  billing_account     = var.billing_account
  labels              = var.labels
  auto_create_network = false
  deletion_policy     = "DELETE" # Allow terraform destroy

  # 참고: 프로덕션 환경에서 삭제 방지가 필요한 경우
  # 아래 lifecycle 블록의 주석을 해제하세요
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 1) 필수 API
resource "google_project_service" "services" {
  project            = google_project.this.project_id
  for_each           = toset(var.apis)
  service            = each.key
  disable_on_destroy = false
}

# 2) Budget(간단 템플릿)
resource "google_billing_budget" "budget" {
  count           = var.enable_budget ? 1 : 0
  billing_account = var.billing_account
  display_name    = "${var.project_id}-budget"

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = var.budget_amount
    }
  }

  budget_filter {
    projects = ["projects/${google_project.this.number}"]
  }

  threshold_rules { threshold_percent = 0.8 }
  threshold_rules { threshold_percent = 1.0 }
}

# 3) 프로젝트 로그 버킷(기본 30일) + 보존기간 설정
resource "time_sleep" "wait_for_logging_api" {
  depends_on      = [google_project_service.services]
  create_duration = var.manage_default_logging_bucket ? var.logging_api_wait_duration : "0s"
}

resource "google_logging_project_bucket_config" "default" {
  count          = var.manage_default_logging_bucket ? 1 : 0
  project        = google_project.this.project_id
  location       = "global"
  retention_days = var.log_retention_days
  bucket_id      = "_Default"

  depends_on = [google_project_service.services, time_sleep.wait_for_logging_api]
}

# 4) CMEK 참조(옵션) – 실제 키는 외부에서 제공
#    var.cmek_key_id 예: projects/<p>/locations/<r>/keyRings/<kr>/cryptoKeys/<key>
resource "google_project_service_identity" "logging_sa" {
  count    = var.manage_default_logging_bucket && var.cmek_key_id != "" ? 1 : 0
  provider = google-beta
  service  = "logging.googleapis.com"
  project  = google_project.this.project_id

  depends_on = [google_project_service.services]
}

resource "google_kms_crypto_key_iam_member" "cmek_bind_logging" {
  count         = var.manage_default_logging_bucket && var.cmek_key_id != "" ? 1 : 0
  crypto_key_id = var.cmek_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.logging_sa[0].email}"
}

output "project_number" { value = google_project.this.number }
output "project_id" { value = google_project.this.project_id }
