terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 5.30" }
  }
  # Local backend - bootstrap 프로젝트는 로컬에 state 저장
  backend "local" {
    path = "terraform.tfstate"
  }
}

# 1) 관리용 프로젝트 생성
resource "google_project" "mgmt" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  folder_id       = var.folder_id
  labels          = var.labels

  auto_create_network = false
  deletion_policy     = "PREVENT" # 실수로 삭제 방지
}

# 2) 필수 API 활성화
resource "google_project_service" "apis" {
  for_each = toset([
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
  ])

  project            = google_project.mgmt.project_id
  service            = each.key
  disable_on_destroy = false
}

# 3) Terraform State 저장용 버킷 생성
resource "google_storage_bucket" "tfstate_prod" {
  project       = google_project.mgmt.project_id
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
      num_newer_versions = 10 # 최근 10개 버전만 유지
      days_since_noncurrent_time = 30 # 30일 지난 버전 삭제
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, {
    purpose = "terraform-state"
    environment = "prod"
  })

  depends_on = [google_project_service.apis]
}

# 4) Dev 환경용 버킷 (선택사항)
resource "google_storage_bucket" "tfstate_dev" {
  count = var.create_dev_bucket ? 1 : 0

  project       = google_project.mgmt.project_id
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
      num_newer_versions = 5
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, {
    purpose = "terraform-state"
    environment = "dev"
  })

  depends_on = [google_project_service.apis]
}

# 5) Jenkins Terraform 자동화용 Service Account 생성
resource "google_service_account" "jenkins_terraform" {
  project      = google_project.mgmt.project_id
  account_id   = "jenkins-terraform-admin"
  display_name = "Jenkins Terraform Admin"
  description  = "Service Account for Jenkins to create and manage GCP projects via Terraform/Terragrunt"

  depends_on = [google_project_service.apis]
}

# 6) 조직 레벨 권한 부여 (프로젝트 생성 권한)
resource "google_organization_iam_member" "jenkins_project_creator" {
  count = var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

# 7) 조직 레벨 권한 부여 (청구 계정 연결 권한)
resource "google_organization_iam_member" "jenkins_billing_user" {
  count = var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/billing.user"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

# 8) 조직 레벨 권한 부여 (리소스 관리 권한)
resource "google_organization_iam_member" "jenkins_editor" {
  count = var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/editor"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

# 폴더 레벨 권한 (조직 ID가 없고 폴더 ID가 있을 경우)
resource "google_folder_iam_member" "jenkins_project_creator_folder" {
  count = var.organization_id == "" && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_folder_iam_member" "jenkins_billing_user_folder" {
  count = var.organization_id == "" && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/billing.user"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_folder_iam_member" "jenkins_editor_folder" {
  count = var.organization_id == "" && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/editor"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}
