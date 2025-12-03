# =============================================================================
# 10-network Terragrunt Configuration
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# =============================================================================
# Locals
# =============================================================================
locals {
  parent_dir = abspath("${get_terragrunt_dir()}/..")

  # 공통 입력 읽기 (HCL 파일 직접 파싱)
  common_vars = read_terragrunt_config("${local.parent_dir}/common.hcl")

  # 레이어 입력 읽기
  layer_vars = read_terragrunt_config("${get_terragrunt_dir()}/layer.hcl")

  # projects map에서 추출
  projects = local.common_vars.locals.projects

  # 각 프로젝트별 VPC Peering 정보 (key = network_url)
  # 새 프로젝트 추가 시: common.hcl의 projects에 추가하면 자동 반영
  project_vpc_peerings = {
    for key, project in local.projects :
    key => project.network_url
  }

  # 프로젝트별 PSC IP 주소 (main.tf에서 terraform_remote_state와 조합)
  project_psc_ips = {
    for key, project in local.projects :
    key => project.psc_ips
  }
}

# 00-foundation 의존성 (실행 순서 보장용)
dependency "foundation" {
  config_path = "../00-foundation"

  # local backend 사용 시에도 동작하도록 skip_outputs 설정
  skip_outputs = true
}

# =============================================================================
# Cross-Project PSC Endpoints 설정 안내
# =============================================================================
# PSC Endpoints는 main.tf에서 terraform_remote_state를 사용하여 생성됩니다.
#
# 이유: bootstrap과 gcp-gcby는 서로 다른 Jenkins Job에서 실행되므로
#       Terragrunt dependency 블록이 작동하지 않습니다.
#       대신 GCS State에서 직접 outputs를 읽어옵니다.
#
# 새 프로젝트 추가 시:
#   1. common.hcl의 projects에 psc_ips 추가
#   2. main.tf에 data "terraform_remote_state" 블록 추가
#   3. main.tf의 locals에서 PSC endpoints 정의 추가
#
# PSC Endpoints 활성화:
#   - 처음 배포 시: enable_psc_endpoints = false (기본값)
#   - gcp-gcby 60-database, 65-cache 배포 후: enable_psc_endpoints = true
# =============================================================================

dependencies {
  paths = ["../00-foundation"]
}

# =============================================================================
# Inputs
# =============================================================================
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    # VPC Peering 대상 목록 (자동 생성)
    project_vpc_network_urls = local.project_vpc_peerings

    # PSC IP 주소 (main.tf에서 terraform_remote_state와 조합하여 사용)
    project_psc_ips = local.project_psc_ips

    # PSC Endpoints 활성화 여부
    # gcp-gcby 60-database, 65-cache가 배포된 후 true로 설정
    enable_psc_endpoints = true
  }
)
