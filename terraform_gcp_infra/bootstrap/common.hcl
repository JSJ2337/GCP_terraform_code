# Bootstrap 공통 설정
# 모든 레이어에서 공유하는 값들

locals {
  # GCP 조직 정보 (delabsgames.gg)
  organization_id = "1034166519592"
  billing_account = "01B77E-0A986D-CB2651"

  # 관리 프로젝트 정보
  management_project_id   = "delabs-gcp-mgmt"
  management_project_name = "delabs-gcp-mgmt"

  # Jenkins Service Account (00-foundation에서 생성됨)
  # 패턴: {account_id}@{project_id}.iam.gserviceaccount.com
  jenkins_service_account_email = "jenkins-terraform-admin@delabs-gcp-mgmt.iam.gserviceaccount.com"

  # 공통 레이블
  labels = {
    managed_by  = "terraform"
    purpose     = "bootstrap"
    team        = "system"
    cost_center = "infrastructure"
  }

  # 리전 설정 (한국 리전 전용)
  region_primary = "asia-northeast3"
  region_backup  = "asia-northeast3"

  # 네트워크 정보 (10-network에서 생성됨)
  # 형식: projects/{project}/global/networks/{network}
  vpc_self_link    = "projects/delabs-gcp-mgmt/global/networks/delabs-gcp-mgmt-vpc"
  subnet_self_link = "projects/delabs-gcp-mgmt/regions/asia-northeast3/subnetworks/delabs-gcp-mgmt-subnet"
}
