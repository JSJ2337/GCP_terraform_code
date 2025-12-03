include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  # region_primary에서 자동으로 zone 생성
  region_primary = local.common_inputs.region_primary

  # common.naming.tfvars에서 VM IP 및 project_name 가져오기
  vm_ips       = try(local.common_inputs.network_config.vm_ips, {})
  project_name = local.common_inputs.project_name

  # instances의 키를 "${project_name}-${key}" 형태로 변환하고
  # zone을 region_primary 기반으로 자동 변환
  # vm_ip_key가 있으면 common.naming.tfvars의 vm_ips에서 network_ip 자동 주입
  instances_with_zones = {
    for k, v in try(local.layer_inputs.instances, {}) :
    "${local.project_name}-${k}" => merge(v, {
      zone       = "${local.region_primary}-${v.zone_suffix}"
      network_ip = try(local.vm_ips[v.vm_ip_key], try(v.network_ip, null))
    })
  }

  # instance_groups의 키도 "${project_name}-${key}" 형태로 변환하고 zone 자동 생성
  instance_groups_with_zones = {
    for k, v in try(local.layer_inputs.instance_groups, {}) :
    "${local.project_name}-${k}" => merge(v, {
      zone = "${local.region_primary}-${v.zone_suffix}"
    })
  }
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
    # 네트워크 레이어에서 서브넷 정보 가져오기
    subnets = dependency.network.outputs.subnets
    # region_primary 기반으로 zone 자동 생성된 instances와 instance_groups
    # network_ip도 common.naming.tfvars의 vm_ips에서 동적 주입
    instances       = local.instances_with_zones
    instance_groups = local.instance_groups_with_zones
  }
)

dependencies {
  paths = [
    "../00-project",
    "../10-network",
    "../30-security"
  ]
}
