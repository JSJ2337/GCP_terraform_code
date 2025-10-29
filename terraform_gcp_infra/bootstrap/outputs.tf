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
  value = <<-EOT

  # 다른 프로젝트의 backend.tf에 사용:
  terraform {
    backend "gcs" {
      bucket = "${google_storage_bucket.tfstate_prod.name}"
      prefix = "your-project-name/layer-name"
    }
  }
  EOT
}
