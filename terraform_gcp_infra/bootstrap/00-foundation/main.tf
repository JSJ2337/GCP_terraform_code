# =============================================================================
# 00-foundation: 기본 인프라 (폴더, 프로젝트, API, IAM)
# =============================================================================

# -----------------------------------------------------------------------------
# 0) 폴더 구조 생성 (게임별로 다른 리전 조합 지원)
# -----------------------------------------------------------------------------
locals {
  # 게임-리전 조합 생성 (var.product_regions에서 가져옴 - layer.hcl에서 관리)
  product_region_combinations = flatten([
    for product, regions in var.product_regions : [
      for region in regions : {
        key     = "${product}/${region}"
        product = product
        region  = region
      }
    ]
  ])

  # 게임-리전-환경 전체 조합 생성
  folder_combinations = flatten([
    for product, regions in var.product_regions : [
      for region in regions : [
        for env in var.environments : {
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
  for_each            = var.manage_folders ? toset(keys(var.product_regions)) : toset([])
  display_name        = each.key
  parent              = "organizations/${var.organization_id}"
  deletion_protection = false
}

# 2단계: 리전 폴더 (각 게임마다 다른 리전 조합)
resource "google_folder" "regions" {
  for_each = var.manage_folders ? {
    for combo in local.product_region_combinations : combo.key => combo
  } : {}

  display_name        = each.value.region
  parent              = google_folder.products[each.value.product].name
  deletion_protection = false
}

# 3단계: 환경 폴더 (LIVE, Staging, GQ-dev)
resource "google_folder" "environments" {
  for_each = var.manage_folders ? {
    for combo in local.folder_combinations : combo.key => combo
  } : {}

  display_name        = each.value.env
  parent              = google_folder.regions["${each.value.product}/${each.value.region}"].name
  deletion_protection = false
}

# -----------------------------------------------------------------------------
# 1) 관리용 프로젝트 (이미 존재하는 경우 data source로 참조)
# -----------------------------------------------------------------------------
# 프로젝트가 이미 gcloud로 생성되어 있으므로 data source 사용
# 새 프로젝트 생성이 필요하면 var.create_project = true로 설정
data "google_project" "mgmt_existing" {
  count      = var.create_project ? 0 : 1
  project_id = var.management_project_id
}

resource "google_project" "mgmt" {
  count = var.create_project ? 1 : 0

  project_id      = var.management_project_id
  name            = var.management_project_name
  billing_account = var.billing_account
  folder_id       = var.folder_id
  labels          = var.labels

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

locals {
  # 프로젝트 ID (생성 또는 기존 참조)
  mgmt_project_id = var.create_project ? google_project.mgmt[0].project_id : data.google_project.mgmt_existing[0].project_id
}

# -----------------------------------------------------------------------------
# 2) 필수 API 활성화
# -----------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    # 핵심 API
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    # 보안 및 접근 제어
    "iap.googleapis.com",              # IAP 터널링
    "iamcredentials.googleapis.com",   # SA 토큰 생성
    "secretmanager.googleapis.com",    # Secret Manager
    # 모니터링 및 로깅
    "logging.googleapis.com",          # Cloud Logging
    "monitoring.googleapis.com",       # Cloud Monitoring
    # OS 관리
    "osconfig.googleapis.com",         # OS 패치 관리
    "oslogin.googleapis.com",          # OS Login
    # DNS
    "dns.googleapis.com",              # Cloud DNS
  ])

  project            = local.mgmt_project_id
  service            = each.key
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# 3) Jenkins Terraform 자동화용 Service Account 생성
# -----------------------------------------------------------------------------
resource "google_service_account" "jenkins_terraform" {
  project      = local.mgmt_project_id
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

# -----------------------------------------------------------------------------
# 7) Bastion 호스트용 Service Account 생성
# -----------------------------------------------------------------------------
resource "google_service_account" "bastion" {
  project      = local.mgmt_project_id
  account_id   = "bastion-host"
  display_name = "Bastion Host Service Account"
  description  = "Service Account for Bastion host to access Cloud DNS and other services"

  depends_on = [google_project_service.apis]
}

# Bastion SA에 DNS Reader 권한 부여 (Cloud DNS 조회용)
resource "google_project_iam_member" "bastion_dns_reader" {
  project = local.mgmt_project_id
  role    = "roles/dns.reader"
  member  = "serviceAccount:${google_service_account.bastion.email}"

  depends_on = [google_service_account.bastion]
}

# Bastion SA에 Compute Viewer 권한 부여 (VM 정보 조회용)
resource "google_project_iam_member" "bastion_compute_viewer" {
  project = local.mgmt_project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.bastion.email}"

  depends_on = [google_service_account.bastion]
}

# -----------------------------------------------------------------------------
# 8) IAP 터널 접근 권한 (관리자용)
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "iap_tunnel_user" {
  for_each = var.iap_tunnel_members

  project = local.mgmt_project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = each.value

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 8) OS Login 권한 (관리자용)
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "os_admin_login" {
  for_each = var.os_login_admins

  project = local.mgmt_project_id
  role    = "roles/compute.osAdminLogin"
  member  = each.value

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "os_login" {
  for_each = var.os_login_users

  project = local.mgmt_project_id
  role    = "roles/compute.osLogin"
  member  = each.value

  depends_on = [google_project_service.apis]
}
