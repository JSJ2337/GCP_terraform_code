# 폴더 구조 출력 (중첩 맵: [product][region][env] = folder_id)
output "folder_structure" {
  description = "전체 폴더 구조. 사용법: folder_structure[\"games\"][\"kr-region\"][\"LIVE\"]"
  value = {
    for product, regions in local.product_regions : product => {
      for region in regions : region => {
        for env in local.environments : env =>
        google_folder.environments["${product}/${region}/${env}"].name
      }
    }
  }
}

# 편의용 단축 출력 (하위 호환성 유지)
output "folder_live_id" {
  description = "games/kr-region/LIVE 폴더 ID (하위 호환용)"
  value       = try(google_folder.environments["games/kr-region/LIVE"].name, null)
}

output "folder_staging_id" {
  description = "games/kr-region/Staging 폴더 ID (하위 호환용)"
  value       = try(google_folder.environments["games/kr-region/Staging"].name, null)
}

output "folder_gq_dev_id" {
  description = "games/kr-region/GQ-dev 폴더 ID (하위 호환용)"
  value       = try(google_folder.environments["games/kr-region/GQ-dev"].name, null)
}

output "project_id" {
  description = "관리용 프로젝트 ID"
  value       = google_project.mgmt.project_id
}

output "project_number" {
  description = "관리용 프로젝트 번호"
  value       = google_project.mgmt.number
}

output "tfstate_bucket_prod" {
  description = "Production Terraform State 버킷 이름"
  value       = google_storage_bucket.tfstate_prod.name
}

output "tfstate_bucket_prod_url" {
  description = "Production Terraform State 버킷 URL"
  value       = google_storage_bucket.tfstate_prod.url
}

output "tfstate_bucket_dev" {
  description = "Development Terraform State 버킷 이름"
  value       = var.create_dev_bucket ? google_storage_bucket.tfstate_dev[0].name : "not created"
}

output "backend_config" {
  description = "다른 프로젝트에서 사용할 backend 설정"
  value       = <<-EOT

  # 다른 프로젝트의 backend.tf에 사용:
  terraform {
    backend "gcs" {
      bucket = "${google_storage_bucket.tfstate_prod.name}"
      prefix = "your-project-name/layer-name"
    }
  }
  EOT
}

output "jenkins_service_account_email" {
  description = "Jenkins Terraform Admin Service Account 이메일"
  value       = google_service_account.jenkins_terraform.email
}

output "jenkins_service_account_name" {
  description = "Jenkins Terraform Admin Service Account 이름"
  value       = google_service_account.jenkins_terraform.name
}

output "jenkins_key_creation_command" {
  description = "Service Account Key 생성 명령어"
  value       = <<-EOT

  # Service Account Key 파일 생성:
  gcloud iam service-accounts keys create jenkins-sa-key.json \
      --iam-account=${google_service_account.jenkins_terraform.email} \
      --project=${google_project.mgmt.project_id}

  # Jenkins Credentials 추가:
  # 1. Jenkins → Manage Jenkins → Credentials
  # 2. (global) → Add Credentials
  # 3. Kind: Secret file
  # 4. File: jenkins-sa-key.json 업로드
  # 5. ID: gcp-service-account
  EOT
}
