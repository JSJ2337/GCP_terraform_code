# =============================================================================
# 00-foundation Outputs
# =============================================================================

# 프로젝트 정보
output "management_project_id" {
  description = "관리용 프로젝트 ID"
  value       = local.mgmt_project_id
}

output "management_project_number" {
  description = "관리용 프로젝트 번호"
  value       = var.create_project ? google_project.mgmt[0].number : data.google_project.mgmt_existing[0].number
}

# Service Account 정보
output "jenkins_service_account_email" {
  description = "Jenkins Terraform SA 이메일"
  value       = google_service_account.jenkins_terraform.email
}

output "jenkins_service_account_id" {
  description = "Jenkins Terraform SA ID"
  value       = google_service_account.jenkins_terraform.id
}

# 폴더 정보
output "product_folder_ids" {
  description = "최상위 제품 폴더 ID 맵"
  value = {
    for k, v in google_folder.products : k => v.folder_id
  }
}

output "region_folder_ids" {
  description = "리전 폴더 ID 맵"
  value = {
    for k, v in google_folder.regions : k => v.folder_id
  }
}

output "environment_folder_ids" {
  description = "환경 폴더 ID 맵"
  value = {
    for k, v in google_folder.environments : k => v.folder_id
  }
}
