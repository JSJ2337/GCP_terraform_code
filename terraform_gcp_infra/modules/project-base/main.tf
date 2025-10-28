terraform {
  required_version = ">= 1.6"
  required_providers {
    google      = { source = "hashicorp/google", version = ">= 5.30" }
    google-beta = { source = "hashicorp/google-beta", version = ">= 5.30" }
  }
}

# 0) 프로젝트 생성 (+ 폴더/결제 연결)
resource "google_project" "this" {
  project_id          = var.project_id
  name                = var.project_name != "" ? var.project_name : var.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  labels              = var.labels
  auto_create_network = false
}

# 1) 필수 API
resource "google_project_service" "services" {
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
resource "google_logging_project_bucket_config" "default" {
  project        = google_project.this.project_id
  location       = "global"
  retention_days = var.log_retention_days
  bucket_id      = "_Default"
}

# 4) CMEK 참조(옵션) – 실제 키는 외부에서 제공
#    var.cmek_key_id 예: projects/<p>/locations/<r>/keyRings/<kr>/cryptoKeys/<key>
resource "google_project_service_identity" "logging_sa" {
  provider = google-beta
  service  = "logging.googleapis.com"
  project  = google_project.this.project_id
}

resource "google_kms_crypto_key_iam_member" "cmek_bind_logging" {
  count         = var.cmek_key_id == "" ? 0 : 1
  crypto_key_id = var.cmek_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.logging_sa.email}"
}

output "project_number" { value = google_project.this.number }
output "project_id" { value = google_project.this.project_id }
