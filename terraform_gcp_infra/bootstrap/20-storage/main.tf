# =============================================================================
# 20-storage: Terraform State 및 공유 스토리지
# =============================================================================

# -----------------------------------------------------------------------------
# 1) Terraform State 저장용 버킷 (Production)
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "tfstate_prod" {
  project       = var.management_project_id
  name          = var.bucket_name_prod
  location      = var.bucket_location
  storage_class = "STANDARD"

  # 실수로 삭제 방지
  force_destroy = false

  # Versioning 활성화 (State 이력 보관)
  versioning {
    enabled = true
  }

  # 균일한 버킷 수준 액세스
  uniform_bucket_level_access = true

  # Lifecycle - 오래된 버전 자동 삭제
  lifecycle_rule {
    condition {
      num_newer_versions         = 10 # 최근 10개 버전만 유지
      days_since_noncurrent_time = 30 # 30일 지난 버전 삭제
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, {
    purpose     = "terraform-state"
    environment = "prod"
  })
}

# -----------------------------------------------------------------------------
# 2) Terraform State 저장용 버킷 (Development) - 선택사항
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "tfstate_dev" {
  count = var.create_dev_bucket ? 1 : 0

  project       = var.management_project_id
  name          = var.bucket_name_dev
  location      = var.bucket_location
  storage_class = "STANDARD"

  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      num_newer_versions         = 5
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, {
    purpose     = "terraform-state"
    environment = "dev"
  })
}

# -----------------------------------------------------------------------------
# 3) 공유 아티팩트 버킷 (빌드 결과물, 패키지 등) - 선택사항
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "artifacts" {
  count = var.create_artifacts_bucket ? 1 : 0

  project       = var.management_project_id
  name          = var.bucket_name_artifacts
  location      = var.bucket_location
  storage_class = "STANDARD"

  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  # 90일 이상 된 객체 Nearline으로 이동
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = merge(var.labels, {
    purpose = "artifacts"
  })
}

# -----------------------------------------------------------------------------
# 4) Jenkins SA에 버킷 권한 부여
# -----------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "jenkins_tfstate_prod" {
  bucket = google_storage_bucket.tfstate_prod.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.jenkins_service_account_email}"
}

resource "google_storage_bucket_iam_member" "jenkins_tfstate_dev" {
  count = var.create_dev_bucket ? 1 : 0

  bucket = google_storage_bucket.tfstate_dev[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.jenkins_service_account_email}"
}

resource "google_storage_bucket_iam_member" "jenkins_artifacts" {
  count = var.create_artifacts_bucket ? 1 : 0

  bucket = google_storage_bucket.artifacts[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.jenkins_service_account_email}"
}
