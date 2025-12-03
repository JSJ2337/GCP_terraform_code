# Bootstrap 공통 설정
# 모든 레이어에서 공유하는 값들
#
# 환경 변수로 민감한 정보 관리:
#   - TG_BOOTSTRAP_ORG_ID: GCP 조직 ID
#   - TG_BOOTSTRAP_BILLING_ACCOUNT: GCP 빌링 계정 ID
#   - TG_BOOTSTRAP_MGMT_PROJECT: 관리 프로젝트 ID (기본값: delabs-gcp-mgmt)

locals {
  # GCP 조직 정보 (환경 변수에서 가져오거나 기본값 사용)
  organization_id = get_env("TG_BOOTSTRAP_ORG_ID", "1034166519592")
  billing_account = get_env("TG_BOOTSTRAP_BILLING_ACCOUNT", "01B77E-0A986D-CB2651")

  # 관리 프로젝트 정보 (환경 변수에서 가져오거나 기본값 사용)
  management_project_id   = get_env("TG_BOOTSTRAP_MGMT_PROJECT", "delabs-gcp-mgmt")
  management_project_name = local.management_project_id  # project_id와 동일하게 유지

  # Jenkins Service Account (동적 생성: 00-foundation에서 생성됨)
  # 패턴: {account_id}@{project_id}.iam.gserviceaccount.com
  jenkins_service_account_email = "jenkins-terraform-admin@${local.management_project_id}.iam.gserviceaccount.com"

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

  # 네트워크 정보 (10-network에서 생성됨 - 동적 생성)
  # 형식: projects/{project}/global/networks/{network}
  vpc_self_link    = "projects/${local.management_project_id}/global/networks/${local.management_project_id}-vpc"
  subnet_self_link = "projects/${local.management_project_id}/regions/${local.region_primary}/subnetworks/${local.management_project_id}-subnet"

  # ========================================================================
  # 프로젝트별 네트워크 설정 (확장 가능한 구조)
  # ========================================================================
  # 새 프로젝트 추가 시 이 map에 추가하면 됩니다.
  # 형식: project_key = { project_id, vpc_name, psc_ips, vm_ips }
  projects = {
    gcby = {
      project_id       = "gcp-gcby"
      environment      = "live"
      vpc_name         = "gcby-live-vpc"
      network_url      = "projects/gcp-gcby/global/networks/gcby-live-vpc"
      has_own_dns_zone = true  # 자체 DNS Zone 있음 - mgmt DNS Zone에서 제외

      # PSC Endpoint IP (mgmt VPC에서 접근용 - mgmt subnet CIDR: 10.250.20.0/24)
      # Redis Cluster는 2개의 Service Attachment가 있으므로 2개의 IP 필요
      psc_ips = {
        cloudsql = "10.250.20.51"
        redis    = ["10.250.20.101", "10.250.20.102"]  # Discovery + Shard
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
