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

  # 추가 Jenkins SA (다른 프로젝트에서 State 버킷 접근 필요한 경우)
  # 현재는 모든 프로젝트가 delabs-gcp-mgmt의 jenkins-terraform-admin SA 사용
  additional_jenkins_sa_emails = []
}
