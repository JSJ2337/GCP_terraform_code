# =============================================================================
# 00-foundation: 기본 인프라 (폴더, 프로젝트, API, IAM)
# =============================================================================

# -----------------------------------------------------------------------------
# 0) 폴더 구조 생성 (게임별로 다른 리전 조합 지원)
# -----------------------------------------------------------------------------
locals {
  # 게임별 사용 리전 매핑 (여기만 수정하면 자동으로 폴더 생성!)
  product_regions = {
    games  = ["kr-region", "us-region"] # games는 한국, 미국
    games2 = ["jp-region", "uk-region"] # games2는 일본, 영국
  }

  # 환경은 모든 게임/리전에서 동일 (고정)
  environments = ["LIVE", "Staging", "GQ-dev"]

  # 게임-리전 조합 생성
  product_region_combinations = flatten([
    for product, regions in local.product_regions : [
      for region in regions : {
        key     = "${product}/${region}"
        product = product
        region  = region
      }
    ]
  ])

  # 게임-리전-환경 전체 조합 생성
  folder_combinations = flatten([
    for product, regions in local.product_regions : [
      for region in regions : [
        for env in local.environments : {
          key     = "${product}/${region}/${env}"
          product = product
          region  = region
          env     = env
        }
      ]
    ]
  ])
}

# 1단계: 최상위 폴더 (games, games2 등)
resource "google_folder" "products" {
  for_each     = var.manage_folders ? toset(keys(local.product_regions)) : toset([])
  display_name = each.key
  parent       = "organizations/${var.organization_id}"
}

# 2단계: 리전 폴더 (각 게임마다 다른 리전 조합)
resource "google_folder" "regions" {
  for_each = var.manage_folders ? {
    for combo in local.product_region_combinations : combo.key => combo
  } : {}

  display_name = each.value.region
  parent       = google_folder.products[each.value.product].name
}

# 3단계: 환경 폴더 (LIVE, Staging, GQ-dev)
resource "google_folder" "environments" {
  for_each = var.manage_folders ? {
    for combo in local.folder_combinations : combo.key => combo
  } : {}

  display_name = each.value.env
  parent       = google_folder.regions["${each.value.product}/${each.value.region}"].name
}

# -----------------------------------------------------------------------------
# 1) 관리용 프로젝트 생성
# -----------------------------------------------------------------------------
resource "google_project" "mgmt" {
  project_id      = var.management_project_id
  name            = var.management_project_name
  billing_account = var.billing_account
  folder_id       = var.folder_id
  labels          = var.labels

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

# -----------------------------------------------------------------------------
# 2) 필수 API 활성화
# -----------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project            = google_project.mgmt.project_id
  service            = each.key
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# 3) Jenkins Terraform 자동화용 Service Account 생성
# -----------------------------------------------------------------------------
resource "google_service_account" "jenkins_terraform" {
  project      = google_project.mgmt.project_id
  account_id   = "jenkins-terraform-admin"
  display_name = "Jenkins Terraform Admin"
  description  = "Service Account for Jenkins to create and manage GCP projects via Terraform/Terragrunt"

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 4) 조직 레벨 권한 부여
# -----------------------------------------------------------------------------
resource "google_organization_iam_member" "jenkins_project_creator" {
  count = var.manage_org_iam && var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_organization_iam_member" "jenkins_billing_user" {
  count = var.manage_org_iam && var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/billing.user"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_organization_iam_member" "jenkins_editor" {
  count = var.manage_org_iam && var.organization_id != "" ? 1 : 0

  org_id = var.organization_id
  role   = "roles/editor"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

# -----------------------------------------------------------------------------
# 5) 폴더 레벨 권한 (조직 ID가 없고 폴더 ID가 있을 경우)
# -----------------------------------------------------------------------------
resource "google_folder_iam_member" "jenkins_project_creator_folder" {
  count = var.organization_id == "" && var.folder_id != null && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_folder_iam_member" "jenkins_billing_user_folder" {
  count = var.organization_id == "" && var.folder_id != null && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/billing.user"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

resource "google_folder_iam_member" "jenkins_editor_folder" {
  count = var.organization_id == "" && var.folder_id != null && var.folder_id != "" ? 1 : 0

  folder = var.folder_id
  role   = "roles/editor"
  member = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}

# -----------------------------------------------------------------------------
# 6) 청구 계정 레벨 권한 부여
# -----------------------------------------------------------------------------
resource "google_billing_account_iam_member" "jenkins_billing_user_on_account" {
  count = var.enable_billing_account_binding ? 1 : 0

  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.jenkins_terraform.email}"
}
