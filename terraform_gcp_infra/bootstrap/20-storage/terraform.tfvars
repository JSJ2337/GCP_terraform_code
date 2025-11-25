# 20-storage 레이어 설정

# Terraform State Buckets
bucket_name_prod = "jsj-terraform-state-prod"
bucket_name_dev  = "jsj-terraform-state-dev"
bucket_location  = "US"

# 버킷 생성 여부
create_dev_bucket       = false
create_artifacts_bucket = false

# 아티팩트 버킷 (선택사항)
bucket_name_artifacts = "jsj-build-artifacts"
