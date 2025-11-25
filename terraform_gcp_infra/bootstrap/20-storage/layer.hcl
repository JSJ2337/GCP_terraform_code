# 20-storage 레이어 설정

locals {
  # Terraform State Buckets
  bucket_name_prod = "delabs-terraform-state-live"
  bucket_name_dev  = "delabs-terraform-state-qa-dev"
  bucket_location  = "ASIA"  # 한국 리전에 맞게 ASIA 설정

  # 버킷 생성 여부
  create_dev_bucket       = false
  create_artifacts_bucket = false

  # 아티팩트 버킷 (선택사항)
  bucket_name_artifacts = "delabs-build-artifacts"
}
