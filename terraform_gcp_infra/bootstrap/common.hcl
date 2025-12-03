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

  # ========================================================================
  # 프로젝트별 네트워크 설정 (확장 가능한 구조)
  # ========================================================================
  # 새 프로젝트 추가 시 이 map에 추가하면 됩니다.
  # 형식: project_key = { project_id, vpc_name, psc_ips, vm_ips }
  projects = {
    gcby = {
      project_id   = "gcp-gcby"
      environment  = "live"
      vpc_name     = "gcby-live-vpc"
      network_url  = "projects/gcp-gcby/global/networks/gcby-live-vpc"

      # PSC Endpoint IP (mgmt VPC에서 접근용)
      # Redis Cluster는 2개의 Service Attachment가 있으므로 2개의 IP 필요
      psc_ips = {
        cloudsql = "10.10.12.51"
        redis    = ["10.10.12.101", "10.10.12.102"]  # Discovery + Shard
      }

      # VM Static IP
      # environments/LIVE/gcp-gcby/common.naming.tfvars의 network_config.vm_ips와 동일하게 유지
      vm_ips = {
        gs01 = "10.10.11.3"
        gs02 = "10.10.11.6"
      }

      # Database/Cache 설정 경로 (dependency용)
      database_path = "../../environments/LIVE/gcp-gcby/60-database"
      cache_path    = "../../environments/LIVE/gcp-gcby/65-cache"
    }

    # 새 프로젝트 추가 예시 (주석)
    # abc = {
    #   project_id   = "gcp-abc"
    #   environment  = "live"
    #   vpc_name     = "abc-live-vpc"
    #   network_url  = "projects/gcp-abc/global/networks/abc-live-vpc"
    #
    #   psc_ips = {
    #     cloudsql = "10.10.13.20"
    #     redis    = ["10.10.13.101", "10.10.13.102"]  # Redis Cluster는 2개 IP 필요
    #   }
    #
    #   vm_ips = {
    #     web01 = "10.20.11.10"
    #   }
    #
    #   database_path = "../../environments/LIVE/gcp-abc/60-database"
    #   cache_path    = "../../environments/LIVE/gcp-abc/65-cache"
    # }
  }
}
