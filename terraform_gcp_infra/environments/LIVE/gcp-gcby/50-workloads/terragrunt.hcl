include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  # Note: terraform.tfvars는 Terraform이 자동으로 로드하므로, 충돌을 피하기 위해 다른 파일명 사용
  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/workloads.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  # ==========================================================================
  # Best Practice: Terragrunt는 값 전달만, 키 변환은 Terraform 모듈에서 처리
  # 단, network_ip는 common.naming.tfvars에서 중앙 관리하므로 여기서 주입
  # Reference: https://www.terraform-best-practices.com/naming
  # ==========================================================================

  # common.naming.tfvars에서 region_primary 가져오기
  region_primary = local.common_inputs.region_primary

  # VM Static IP 맵 (common.naming.tfvars에서 가져오기)
  # 우선순위: vm_static_ips > network_config.vm_ips
  vm_ips = try(
    local.common_inputs.vm_static_ips,
    try(local.common_inputs.network_config.vm_ips, {})
  )

  # instances에 network_ip 주입 (terraform.tfvars의 값 또는 common.naming.tfvars의 중앙 관리 IP)
  # 키 변환은 main.tf에서 처리하므로 여기서는 network_ip만 주입
  # Note: terragrunt read_tfvars_file은 정의되지 않은 속성을 포함하지 않으므로 try/lookup 사용
  instances_with_network_ip = {
    for k, v in try(local.layer_inputs.instances, {}) :
    k => merge(v, {
      # network_ip 우선순위:
      # 1. terraform.tfvars에서 직접 지정 (try로 안전하게 접근)
      # 2. common.naming.tfvars의 vm_static_ips에서 키 이름으로 조회
      network_ip = try(v.network_ip, lookup(local.vm_ips, k, null))
    })
  }

  # instance_groups (키 변환 없이 전달)
  instance_groups_raw = try(local.layer_inputs.instance_groups, {})
}

# 네트워크 레이어 의존성 설정
dependency "network" {
  config_path = "../10-network"

  # 10-network가 아직 apply되지 않았을 때 사용할 mock 데이터
  mock_outputs = {
    subnets = {
      dmz = {
        self_link  = "mock-dmz-subnet"
        region     = local.region_primary
        project_id = "mock-project"
        name       = "mock-dmz"
      }
      private = {
        self_link  = "mock-private-subnet"
        region     = local.region_primary
        project_id = "mock-project"
        name       = "mock-private"
      }
      db = {
        self_link  = "mock-db-subnet"
        region     = local.region_primary
        project_id = "mock-project"
        name       = "mock-db"
      }
    }
    vpc_self_link = "mock-vpc-self-link"
    vpc_name      = "mock-vpc-name"
  }

  # 10-network가 apply되지 않았거나 destroy되었을 때도 mock outputs 사용 가능하도록 설정
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # ==========================================================================
    # Best Practice: inputs는 단순한 값 전달만
    # 복잡한 변환 로직은 Terraform 모듈 (main.tf)에서 처리
    # Reference: https://terragrunt.gruntwork.io/docs/features/inputs/
    # ==========================================================================

    # 네트워크 레이어에서 서브넷 정보 가져오기
    subnets = dependency.network.outputs.subnets

    # instances: network_ip만 주입, 키 변환/zone 변환은 main.tf에서 처리
    instances = local.instances_with_network_ip

    # instance_groups: 그대로 전달, 키 변환/zone 변환은 main.tf에서 처리
    instance_groups = local.instance_groups_raw

    # VM 메타데이터 - common.naming.tfvars의 vm_admin_config에서 주입
    metadata = {
      admin-password = try(local.common_inputs.vm_admin_config.password, "")
    }
  }
)

dependencies {
  paths = [
    "../00-project",
    "../10-network",
    "../30-security"
  ]
}
